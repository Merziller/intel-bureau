"""大屏在线统计：有多少个页面正连着 SSE（/api/events）。

用途：隐藏方式启动时（scripts/start.ps1 -Gui → ``bureau serve --exit-when-idle N``），
所有大屏页面都关掉、并且没有任务在运行，持续 N 秒后服务自己退出。这样不用去猜浏览器窗口的状态
（Edge 的弹出小窗、后台进程都会干扰窗口判断），任何浏览器、任何标签页都适用。

线程安全：SSE 在事件循环里增减计数，退出检查在另一个线程里读取，所以加锁。
"""

from __future__ import annotations

import threading
import time
from typing import Callable


class Presence:
    def __init__(self, clock: Callable[[], float] = time.monotonic) -> None:
        self._clock = clock
        self._lock = threading.Lock()
        self._clients = 0
        self._ever = False
        self._since = clock()          # 最近一次「没有页面连着」开始的时间

    def connect(self) -> None:
        with self._lock:
            self._clients += 1
            self._ever = True

    def disconnect(self) -> None:
        with self._lock:
            self._clients = max(0, self._clients - 1)
            if self._clients == 0:
                self._since = self._clock()

    @property
    def clients(self) -> int:
        with self._lock:
            return self._clients

    @property
    def ever_connected(self) -> bool:
        with self._lock:
            return self._ever

    def idle_seconds(self) -> float:
        """没有任何页面连着已经多少秒；有页面连着时返回 0。"""
        with self._lock:
            return 0.0 if self._clients else max(0.0, self._clock() - self._since)

    def touch(self) -> None:
        """有别的事情在忙（比如任务正在运行）时调用：把空闲计时重新从现在算起。"""
        with self._lock:
            if self._clients == 0:
                self._since = self._clock()


def should_exit(p: Presence, *, idle_after: float, startup_grace: float, busy: bool) -> bool:
    """是否该退出：任务在跑时永远不退；从没有页面连上过时，用较长的启动宽限期。"""
    if busy:
        p.touch()
        return False
    limit = idle_after if p.ever_connected else max(idle_after, startup_grace)
    return p.idle_seconds() >= limit
