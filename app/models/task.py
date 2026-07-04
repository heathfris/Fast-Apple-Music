from dataclasses import dataclass
from enum import Enum
from typing import Callable


class TaskType(Enum):
    CONVERT = "convert"
    READ_TAGS = "read_tags"
    WRITE_TAGS = "write_tags"


@dataclass
class Task:
    task_id: str                     # 唯一标识
    task_type: TaskType
    file_path: str                   # 要处理的文件路径
    kwargs: dict                     # 额外参数（target_format, tags 等）
    _on_progress: Callable = None    # 进度回调

    def __post_init__(self):
        import uuid
        if not self.task_id:
            self.task_id = str(uuid.uuid4())[:8]
