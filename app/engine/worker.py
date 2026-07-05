"""异步任务队列 — 基于 QThread，批量处理不阻塞 UI"""
from PySide6.QtCore import QThread, Signal
from queue import Queue, Empty
from app.models.task import Task, TaskType
from app.models.audiofile import AudioFile, AudioStatus
from app.engine.converter import ConversionEngine


class TaskWorker(QThread):
    """后台任务处理线程"""

    # 信号
    task_started = Signal(str)          # task_id
    task_progress = Signal(str, int)    # task_id, percent (0-100)
    task_finished = Signal(str, object) # task_id, AudioFile (转换后) 或 tags dict
    task_failed = Signal(str, str)      # task_id, error_message
    all_done = Signal()                 # 全部任务完成

    def __init__(self, parent=None):
        super().__init__(parent)
        self._queue = Queue()
        self._cancelled = False
        self._pending_count = 0
        self._engine = ConversionEngine()

    def add_task(self, task: Task):
        """添加任务到队列"""
        self._pending_count += 1
        self._queue.put(task)

    def add_tasks(self, tasks: list[Task]):
        """批量添加任务"""
        for t in tasks:
            self._pending_count += 1
            self._queue.put(t)

    def cancel_all(self):
        """取消所有待处理任务"""
        self._cancelled = True
        # 清空队列
        while not self._queue.empty():
            try:
                self._queue.get_nowait()
            except Empty:
                break

    def run(self):
        """线程主循环 — 逐个处理队列中的任务"""
        self._cancelled = False

        while not self._cancelled:
            try:
                task = self._queue.get(timeout=0.5)
            except Empty:
                continue

            self.task_started.emit(task.task_id)

            try:
                if task.task_type == TaskType.CONVERT:
                    self._run_convert(task)
                elif task.task_type == TaskType.READ_TAGS:
                    self._run_read_tags(task)
                elif task.task_type == TaskType.WRITE_TAGS:
                    self._run_write_tags(task)
            except Exception as e:
                self.task_failed.emit(task.task_id, str(e)[:200])

        self.all_done.emit()

    def _run_convert(self, task: Task):
        """执行转换任务"""
        output_dir = task.kwargs.get("output_dir", "")
        # 优先使用已分析好的 AudioFile，避免重复 ffprobe
        af = task.kwargs.get("audio_file") or self._engine.analyze(task.file_path)

        # 进度模拟（ffmpeg 子进程本身不输出百分比，按阶段汇报）
        self.task_progress.emit(task.task_id, 10)
        result = self._engine.convert(af, output_dir)
        self.task_progress.emit(task.task_id, 100)

        if result.status == AudioStatus.DONE:
            self.task_finished.emit(task.task_id, result)
        else:
            self.task_failed.emit(task.task_id, result.error_message)
        self._decrement_pending()

    def _run_read_tags(self, task: Task):
        """执行标签读取任务"""
        from app.metadata.reader import read_tags
        self.task_progress.emit(task.task_id, 50)
        tags = read_tags(task.file_path)
        self.task_progress.emit(task.task_id, 100)
        self.task_finished.emit(task.task_id, tags)
        self._decrement_pending()

    def _run_write_tags(self, task: Task):
        """执行标签写入任务"""
        from app.metadata.writer import write_tags
        self.task_progress.emit(task.task_id, 50)
        write_tags(task.file_path, task.kwargs.get("tags", {}))
        self.task_progress.emit(task.task_id, 100)
        af = self._engine.analyze(task.file_path)
        af.status = AudioStatus.TAGGED
        self.task_finished.emit(task.task_id, af)
        self._decrement_pending()

    def _decrement_pending(self):
        self._pending_count -= 1
        if self._pending_count <= 0:
            self._pending_count = 0
            self.all_done.emit()
