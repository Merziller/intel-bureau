"""feishu.lark_cli 采集器与 bureau.integrations.lark_cli（假 lark-cli 运行器，不启动子进程）。"""

from __future__ import annotations

from pathlib import Path

import pytest

from bureau.collectors.feishu_lark import LarkCliCollector, normalize_content
from bureau.contracts import GroupInfo, Health, MessageKind, Platform
from bureau.integrations import lark_cli as lc
from bureau.integrations.lark_cli import LarkCli, LarkCliError, extract_json, find_lark_cli

from .helpers import FakeLark, auth_status, collector_ctx, dt, lark_error, run

GROUP = GroupInfo(platform=Platform.FEISHU, native_id="oc_abc", name="产品群")
CHATS = {"chats": [{"chat_id": "oc_abc", "name": "产品群", "chat_mode": "group", "chat_status": "normal"},
                   {"chat_id": "oc_old", "name": "旧群", "chat_status": "dissolved"}], "has_more": False}
MESSAGES = {"messages": [
    {"message_id": "om_1", "msg_type": "text", "content": "大家好 @李四", "create_time": "2026-10-28 07:00",
     "sender": {"id": "ou_a", "sender_type": "user", "name": "张三"}, "deleted": False, "updated": False,
     "mentions": [{"key": "@_user_1", "id": "ou_b", "name": "李四"}]},
    {"message_id": "om_2", "msg_type": "image", "content": "[Image: img_v3_x]", "create_time": "2026-10-28 07:05",
     "sender": {"id": "ou_b", "sender_type": "user", "name": "李四"}, "deleted": False, "thread_id": "omt_1",
     "thread_replies": [{"message_id": "om_3", "msg_type": "post", "create_time": "2026-10-28 07:06",
                         "content": "看这个 [文档](https://example.feishu.cn/docx/1)",
                         "sender": {"id": "cli_bot", "sender_type": "app", "name": "助手"}}]},
    {"message_id": "om_4", "msg_type": "text", "content": "撤回内容", "create_time": "2026-10-28 07:10",
     "sender": {"id": "ou_a", "sender_type": "user", "name": "张三"}, "deleted": True},
    {"message_id": "om_5", "msg_type": "file", "content": '<file key="file_1" name="方案.pdf"/>',
     "create_time": "2026-10-28 08:00", "sender": {"id": "ou_a", "name": "张三"}, "deleted": False},
], "total": 4, "has_more": False, "page_token": ""}


def make(tmp_path, routes, identity="user"):
    fake = FakeLark(routes)
    cli = LarkCli(path="C:/fake/lark-cli.exe", runner=fake)
    ctx = collector_ctx(tmp_path, "feishu", {"identity": identity, "cli_timezone": "Asia/Shanghai"})
    return LarkCliCollector(ctx, cli=cli), fake


def test_health_user_expired_hint(tmp_path):
    c, _ = make(tmp_path, [(("auth", "status"), auth_status(user_status="missing",
                                                            user_msg="User identity: missing (refresh token expired)"))])
    h = run(c.health())
    assert h.state is Health.DOWN and "过期" in h.detail
    assert "在终端运行 `lark-cli auth login` 重新授权" in h.hint


def _needs_refresh_status(refresh_expires_at: str, message: str = "User identity: needs_refresh"):
    """访问令牌（2 小时）已过期的 auth status：tokenStatus 同样是 expired，指的是访问令牌。"""
    import json as _json
    doc = {"appId": "cli_test", "identity": "user", "identities": {
        "bot": {"status": "ready", "available": True, "message": "Bot identity: ready"},
        "user": {"status": "needs_refresh", "available": False, "message": message, "userName": "测试用户",
                 "openId": "ou_test", "tokenStatus": "expired", "refreshExpiresAt": refresh_expires_at,
                 "scope": "im:chat:read im:message.group_msg:get_as_user"}}}
    return 0, _json.dumps(doc, ensure_ascii=False), ""


def test_health_needs_refresh_is_ok_while_refresh_token_valid(tmp_path):
    """访问令牌过期但刷新令牌还在：下一次真实调用会自动续期，健康检查不能报中断（否则用户每次都得重新授权）。"""
    from datetime import datetime, timedelta, timezone
    future = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    c, fake = make(tmp_path, [(("auth", "status"), _needs_refresh_status(future))])
    h = run(c.health())
    assert h.ok and h.state is Health.OK and "待自动续期" in h.detail
    assert [call["args"][:2] for call in fake.calls] == [["auth", "status"]]      # 只读本地状态，不发真实请求


def test_health_needs_refresh_down_when_refresh_token_expired(tmp_path):
    from datetime import datetime, timedelta, timezone
    past = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    c, _ = make(tmp_path, [(("auth", "status"), _needs_refresh_status(past))])
    h = run(c.health())
    assert h.state is Health.DOWN and "过期" in h.detail
    assert "在终端运行 `lark-cli auth login` 重新授权" in h.hint


def test_health_needs_refresh_down_when_message_says_refresh_expired(tmp_path):
    from datetime import datetime, timedelta, timezone
    future = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    c, _ = make(tmp_path, [(("auth", "status"),
                            _needs_refresh_status(future, "User identity: needs_refresh (refresh token expired)"))])
    assert run(c.health()).state is Health.DOWN


def test_health_bot_not_in_any_chat(tmp_path):
    c, fake = make(tmp_path, [(("auth", "status"), auth_status()),
                              (("im", "+chat-list"), {"chats": None, "has_more": False})], identity="bot")
    h = run(c.health())
    assert h.state is Health.DEGRADED and h.hint == "把机器人拉进要监控的群，或改用用户身份"
    assert fake.calls[1]["args"][:4] == ["im", "+chat-list", "--as", "bot"]


def test_health_ok_and_missing_cli(tmp_path, monkeypatch):
    c, _ = make(tmp_path, [(("auth", "status"), auth_status())])
    assert run(c.health()).ok
    monkeypatch.setattr(lc, "find_lark_cli", lambda cli_path=None: (None, []))   # 不碰本机真实的 lark-cli
    missing = LarkCliCollector(collector_ctx(tmp_path, "feishu", {}), cli=LarkCli(runner=FakeLark([])))
    h = run(missing.health())
    assert h.state is Health.UNCONFIGURED and lc.INSTALL_HINT in h.hint


def test_list_groups(tmp_path):
    c, fake = make(tmp_path, [(("im", "+chat-list"), CHATS)])
    groups = run(c.list_groups())
    assert [g.native_id for g in groups] == ["oc_abc"]
    assert fake.calls[0]["args"][:6] == ["im", "+chat-list", "--as", "user", "--page-all", "--page-limit"]


def test_fetch_messages_args_and_mapping(tmp_path):
    c, fake = make(tmp_path, [(("im", "+chat-messages-list"), MESSAGES)])
    res = run(c.fetch_messages(GROUP, dt("2026-10-28 06:59:30"), dt("2026-10-28 08:00"), limit=120))
    args = fake.calls[0]["args"]
    for flag, val in (("--chat-id", "oc_abc"), ("--start", "2026-10-28T06:59:30+08:00"),
                      ("--end", "2026-10-28T08:00:00+08:00"), ("--order", "asc"), ("--page-limit", "3"),
                      ("--as", "user")):
        assert args[args.index(flag) + 1] == val
    assert "--page-all" in args and "--no-reactions" in args
    ids = [m.native_id for m in res.messages]
    assert ids == ["om_1", "om_2", "om_3", "om_4"]           # 07:00 按分钟取整仍在窗口内；08:00 不含
    one, img, reply, recalled = res.messages
    assert one.sender_name == "张三" and one.mentions == ["ou_b"] and one.kind is MessageKind.TEXT
    assert img.kind is MessageKind.IMAGE and img.text == "[图片]" and img.attachments[0].extra["image_key"] == "img_v3_x"
    assert reply.reply_to == "om_2" and reply.kind is MessageKind.REPLY and reply.sender_name == "助手"
    assert reply.attachments[0].url == "https://example.feishu.cn/docx/1"
    assert recalled.kind is MessageKind.RECALL and recalled.text == "[已撤回]"
    assert one.sent_at.isoformat() == "2026-10-28T07:00:00+08:00"


def test_fetch_error_is_chinese(tmp_path):
    c, _ = make(tmp_path, [(("im", "+chat-messages-list"),
                            lark_error("authentication", "need_user_authorization", subtype="token_missing"))])
    with pytest.raises(RuntimeError, match="lark-cli auth login"):
        run(c.fetch_messages(GROUP, dt("2026-10-28 06:00"), dt("2026-10-28 08:00")))


def test_normalize_content_markers():
    text, atts = normalize_content("post", "说明\n<file key=\"f\" name=\"a.zip\"/>\n<audio key=\"k\" duration=\"3s\"/>")
    assert text == "说明\n[文件] a.zip\n[语音 3s]" and [a.kind for a in atts] == ["file", "voice"]
    assert normalize_content("sticker", "[Sticker]")[0] == "[表情]"


def test_extract_json_skips_log_lines():
    out = "[lark-cli] uat-client: refreshing\n{\"ok\": true, \"data\": {\"x\": 1}}"
    assert extract_json(out) == {"ok": True, "data": {"x": 1}}
    assert extract_json("no json here") is None


def test_error_envelope_mapping():
    async def go(resp):
        return await LarkCli(path="x.exe", runner=FakeLark([((), resp)])).run(["im"], identity="bot")
    with pytest.raises(LarkCliError) as e:
        run(go(lark_error("authorization", "denied", subtype="missing_scope", identity="bot",
                          missing_scopes=["im:message:send_as_bot"])))
    assert "缺少权限" in e.value.message and "开发者后台" in e.value.hint
    with pytest.raises(LarkCliError) as e:
        run(go(lark_error("api", "frequency limit", code=99991400)))
    assert e.value.retryable and "限流" in e.value.message
    with pytest.raises(LarkCliError) as e:
        run(go((10, "", '{"ok":false,"error":{"type":"confirmation_required","message":"high-risk"}}')))
    assert e.value.kind == "confirm"


def test_cmd_shim_rejects_special_chars():
    cli = LarkCli(path="C:/x/lark-cli.cmd", runner=FakeLark([]))
    with pytest.raises(LarkCliError, match="特殊字符"):
        run(cli.run(["docs", "+create", "--title", "a|b"]))


def test_find_order(tmp_path, monkeypatch):
    explicit = tmp_path / "my-lark.exe"
    explicit.write_text("")
    monkeypatch.setattr(lc.shutil, "which", lambda name: None)
    monkeypatch.setattr(lc, "LOCAL_CMD", tmp_path / "nope.cmd")
    monkeypatch.setattr(lc, "WORKBUDDY_EXE", tmp_path / "wb.exe")
    assert find_lark_cli(str(explicit)) == (str(explicit), [])
    path, notes = find_lark_cli(str(tmp_path / "missing.exe"))
    assert path is None and "不存在" in notes[0]
    # 名字跟着平台走：Windows 是 npm 的 lark-cli.cmd 外壳 + lark-cli.exe 原生，
    # macOS / Linux 是同一目录下无扩展名的 lark-cli
    shim = tmp_path / "node_modules" / ".bin" / lc.LOCAL_CMD.name
    native = tmp_path / "node_modules" / lc._PKG_BIN / lc._PKG_EXE
    for p in (shim, native):
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("")
    monkeypatch.setattr(lc, "LOCAL_CMD", shim)
    assert find_lark_cli(None)[0] == str(native)                    # .cmd 外壳换成原生 exe
    (tmp_path / "wb.exe").write_text("")
    monkeypatch.setattr(lc.shutil, "which", lambda name: str(tmp_path / "wb.exe"))
    assert Path(find_lark_cli(None)[0]).name == "wb.exe"            # PATH 优先于本地安装