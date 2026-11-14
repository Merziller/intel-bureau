"""隐藏方式启动：大屏全部关闭、且没有任务在跑，持续 N 秒后服务自己退出。"""

from __future__ import annotations

import time
from types import SimpleNamespace

from bureau.core.presence import Presence, should_exit


class Clock:
    def __init__(self) -> None:
        self.t = 1000.0

    def __call__(self) -> float:
        return self.t


def test_idle_counts_only_when_no_client():
    c = Clock()
    p = Presence(clock=c)
    p.connect()
    c.t += 100
    assert p.idle_seconds() == 0 and p.clients == 1
    p.disconnect()
    c.t += 7
    assert p.idle_seconds() == 7


def test_reload_does_not_trigger_exit():
    """刷新页面：旧连接断开、新连接马上接上，不能被当成「关闭了」。"""
    c = Clock()
    p = Presence(clock=c)
    p.connect()
    p.disconnect()
    c.t += 1
    p.connect()
    c.t += 60
    assert not should_exit(p, idle_after=20, startup_grace=120, busy=False)


def test_two_tabs_need_both_closed():
    c = Clock()
    p = Presence(clock=c)
    p.connect(); p.connect()
    p.disconnect()
    c.t += 60
    assert not should_exit(p, idle_after=20, startup_grace=120, busy=False)
    p.disconnect()
    c.t += 21
    assert should_exit(p, idle_after=20, startup_grace=120, busy=False)


def test_startup_grace_before_any_page_connects():
    """窗口还没打开（浏览器冷启动慢）时用较长的宽限期，不能刚启动就退出。"""
    c = Clock()
    p = Presence(clock=c)
    c.t += 60
    assert not should_exit(p, idle_after=20, startup_grace=120, busy=False)
    c.t += 61
    assert should_exit(p, idle_after=20, startup_grace=120, busy=False)


def test_running_task_blocks_exit_and_restarts_idle_clock():
    """窗口关了但任务在跑：不退出；任务结束后要再空闲满 N 秒才退出。"""
    c = Clock()
    p = Presence(clock=c)
    p.connect(); p.disconnect()
    c.t += 600
    assert not should_exit(p, idle_after=20, startup_grace=120, busy=True)
    c.t += 5
    assert not should_exit(p, idle_after=20, startup_grace=120, busy=False)
    c.t += 16
    assert should_exit(p, idle_after=20, startup_grace=120, busy=False)


def test_idle_watch_stops_server():
    from bureau.cli import _start_idle_watch

    p = Presence()
    p.connect(); p.disconnect()
    ctx = SimpleNamespace(presence=p, runner=SimpleNamespace(busy=False))
    server = SimpleNamespace(should_exit=False)
    t = _start_idle_watch(ctx, server, 0.2, startup_grace=0.2, poll=0.05)
    t.join(timeout=3)
    assert server.should_exit is True


def test_idle_watch_waits_for_running_task():
    from bureau.cli import _start_idle_watch

    p = Presence()
    p.connect(); p.disconnect()
    runner = SimpleNamespace(busy=True)
    ctx = SimpleNamespace(presence=p, runner=runner)
    server = SimpleNamespace(should_exit=False)
    _start_idle_watch(ctx, server, 0.2, startup_grace=0.2, poll=0.05)
    time.sleep(0.6)
    assert server.should_exit is False                     # 任务在跑，不退
    runner.busy = False
    deadline = time.time() + 3
    while not server.should_exit and time.time() < deadline:
        time.sleep(0.05)
    assert server.should_exit is True
