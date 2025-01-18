import subprocess
import sys
import os
from PySide6.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QPushButton,
    QListWidget,
    QMessageBox,
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QDragEnterEvent, QDropEvent
from natsort import natsorted  # natsort를 사용해 자연스러운 정렬 구현


class FileDropListWidget(QListWidget):
    def __init__(self, valid_extensions=None, parent=None):
        super().__init__(parent)
        self.valid_extensions = valid_extensions or []  # 허용할 파일 확장자 목록
        self.setAcceptDrops(True)  # 외부 드롭 허용

    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.accept()
        else:
            event.ignore()

    def dragMoveEvent(self, event: QDragEnterEvent):
        event.accept()

    def dropEvent(self, event: QDropEvent):
        if event.mimeData().hasUrls():
            files = []
            for url in event.mimeData().urls():
                if url.isLocalFile():
                    file_path = url.toLocalFile()
                    if os.path.isdir(file_path):
                        # 폴더일 경우 내부 파일 탐색
                        for root, _, filenames in os.walk(file_path):
                            for filename in filenames:
                                full_path = os.path.join(root, filename)
                                if not self.valid_extensions or full_path.split(".")[-1].lower() in self.valid_extensions:
                                    files.append(full_path)
                    else:
                        # 파일일 경우
                        if not self.valid_extensions or file_path.split(".")[-1].lower() in self.valid_extensions:
                            files.append(file_path)
            self.parent().handle_file_drop(self, files)
            event.accept()
        else:
            event.ignore()


class EZSubtitlesApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("E.Z Subtitles")
        self.resize(600, 400)

        # Layout setup
        main_layout = QVBoxLayout()
        self.setLayout(main_layout)

        # Initialize lists
        self.video_full_paths = []
        self.subtitle_full_paths = []

        # Top buttons
        open_disk_button = QPushButton("전체 디스크 접근 설정 열기")
        open_disk_button.clicked.connect(self.open_disk_access_settings)
        main_layout.addWidget(open_disk_button)

        # File lists with move buttons
        file_list_layout = QHBoxLayout()

        # Video list and move buttons
        video_layout = QVBoxLayout()
        self.video_list = FileDropListWidget(valid_extensions=["mp4", "mkv"], parent=self)
        move_video_up_button = QPushButton("▲ 동영상 위로")
        move_video_down_button = QPushButton("▼ 동영상 아래로")
        move_video_up_button.clicked.connect(lambda: self.move_item(self.video_full_paths, self.video_list, -1))
        move_video_down_button.clicked.connect(lambda: self.move_item(self.video_full_paths, self.video_list, 1))
        video_layout.addWidget(self.video_list)
        video_layout.addWidget(move_video_up_button)
        video_layout.addWidget(move_video_down_button)

        # Subtitle list and move buttons
        subtitle_layout = QVBoxLayout()
        self.subtitle_list = FileDropListWidget(valid_extensions=["smi", "srt", "ass"], parent=self)
        move_subtitle_up_button = QPushButton("▲ 자막 위로")
        move_subtitle_down_button = QPushButton("▼ 자막 아래로")
        move_subtitle_up_button.clicked.connect(lambda: self.move_item(self.subtitle_full_paths, self.subtitle_list, -1))
        move_subtitle_down_button.clicked.connect(lambda: self.move_item(self.subtitle_full_paths, self.subtitle_list, 1))
        subtitle_layout.addWidget(self.subtitle_list)
        subtitle_layout.addWidget(move_subtitle_up_button)
        subtitle_layout.addWidget(move_subtitle_down_button)

        file_list_layout.addLayout(video_layout)
        file_list_layout.addLayout(subtitle_layout)
        main_layout.addLayout(file_list_layout)

        # Bottom buttons
        button_layout = QHBoxLayout()
        sort_videos_button = QPushButton("동영상 정렬")
        sort_subtitles_button = QPushButton("자막 정렬")
        reset_videos_button = QPushButton("동영상 목록 초기화")
        reset_subtitles_button = QPushButton("자막 목록 초기화")
        sync_button = QPushButton("파일 이름 동기화")

        sort_videos_button.clicked.connect(lambda: self.sort_files(self.video_full_paths, self.video_list))
        sort_subtitles_button.clicked.connect(lambda: self.sort_files(self.subtitle_full_paths, self.subtitle_list))
        reset_videos_button.clicked.connect(lambda: self.reset_list(self.video_full_paths, self.video_list))
        reset_subtitles_button.clicked.connect(lambda: self.reset_list(self.subtitle_full_paths, self.subtitle_list))
        sync_button.clicked.connect(self.sync_file_names)

        button_layout.addWidget(sort_videos_button)
        button_layout.addWidget(sort_subtitles_button)
        button_layout.addWidget(reset_videos_button)
        button_layout.addWidget(reset_subtitles_button)
        main_layout.addLayout(button_layout)
        main_layout.addWidget(sync_button)

    def open_disk_access_settings(self):
        #QMessageBox.information(self, "디스크 접근 설정", "디스크 접근 설정은 수동으로 설정해야 합니다.")
        url = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        try:
            subprocess.run(["open", url], check=True)
            print("Opened Full Disk Access settings.")
        except subprocess.CalledProcessError as e:
            print(f"Failed to open settings: {e}")

    def handle_file_drop(self, list_widget, files):
        if list_widget == self.video_list:
            self.video_full_paths.extend(files)
            self.update_list_widget(self.video_list, self.video_full_paths)
        elif list_widget == self.subtitle_list:
            self.subtitle_full_paths.extend(files)
            self.update_list_widget(self.subtitle_list, self.subtitle_full_paths)

    def move_item(self, full_paths, list_widget, direction):
        current_row = list_widget.currentRow()
        if current_row == -1:
            return

        target_row = current_row + direction
        if 0 <= target_row < len(full_paths):
            full_paths.insert(target_row, full_paths.pop(current_row))
            self.update_list_widget(list_widget, full_paths)
            list_widget.setCurrentRow(target_row)  # 현재 선택 유지

    def sort_files(self, full_paths, list_widget):
        current_row = list_widget.currentRow()
        current_file = full_paths[current_row] if current_row != -1 else None

        full_paths[:] = natsorted(full_paths, key=lambda x: os.path.basename(x))
        self.update_list_widget(list_widget, full_paths)

        if current_file in full_paths:
            new_index = full_paths.index(current_file)
            list_widget.setCurrentRow(new_index)  # 정렬 후 선택된 항목 유지

    def reset_list(self, full_paths, list_widget):
        full_paths.clear()
        self.update_list_widget(list_widget, full_paths)

    def sync_file_names(self):
        if len(self.video_full_paths) != len(self.subtitle_full_paths):
            QMessageBox.warning(self, "파일 개수 불일치", "동영상과 자막 파일의 개수가 다릅니다.")
            return

        success_count, failure_count = 0, 0
        failed_files = []
        duplicate_files = []

        for i, (video, subtitle) in enumerate(zip(self.video_full_paths, self.subtitle_full_paths)):
            video_base = os.path.splitext(os.path.basename(video))[0]
            subtitle_extension = os.path.splitext(subtitle)[-1]
            new_subtitle_name = f"{video_base}{subtitle_extension}"
            subtitle_dir = os.path.dirname(subtitle)
            new_subtitle_path = os.path.join(subtitle_dir, new_subtitle_name)

            # 파일 이름 중복 방지
            if os.path.exists(new_subtitle_path):
                duplicate_files.append(new_subtitle_name)
                failure_count += 1
                continue

            try:
                os.rename(subtitle, new_subtitle_path)
                self.subtitle_full_paths[i] = new_subtitle_path  # 목록에 변경 사항 반영
                success_count += 1
            except OSError:
                failed_files.append(subtitle)
                failure_count += 1

        self.update_list_widget(self.subtitle_list, self.subtitle_full_paths)  # 목록 업데이트

        message = f"{success_count}개의 파일 이름이 변경되었습니다."
        if failure_count > 0:
            if duplicate_files:
                message += f"\n다음 파일 이름이 중복되어 변경되지 않았습니다:\n" + "\n".join(duplicate_files)
            if failed_files:
                message += f"\n다음 파일의 이름 변경에 실패했습니다:\n" + "\n".join(failed_files)

        QMessageBox.information(self, "동기화 완료", message)

    def update_list_widget(self, list_widget, full_paths):
        list_widget.clear()
        list_widget.addItems([os.path.basename(path) for path in full_paths])


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = EZSubtitlesApp()
    window.show()
    sys.exit(app.exec())