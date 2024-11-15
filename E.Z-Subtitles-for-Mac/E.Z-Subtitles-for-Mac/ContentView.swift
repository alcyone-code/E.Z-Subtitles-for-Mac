import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var leftFileURLs: [URL] = []  // 동영상 파일 URL
    @State private var rightFileURLs: [URL] = [] // 자막 파일 URL
    @State private var dragOverLeft = false      // 왼쪽 드래그 상태
    @State private var dragOverRight = false     // 오른쪽 드래그 상태
    @State private var showAlert = false         // 경고 메시지 표시 여부
    @State private var alertTitle: String?       // 경고 메시지 제목
    @State private var alertMessage: String?     // 경고 메시지 내용
    @State private var draggedItem: URL?         // 현재 드래그 중인 아이템
    @State private var isFirstDropLeft = true    // 왼쪽 목록 첫 드롭 여부
    @State private var isFirstDropRight = true   // 오른쪽 목록 첫 드롭 여부
    
    var body: some View {
        VStack {
            Button(action: openFullDiskAccessSettings){
                Text("전체 디스크 접근 설정 열기")
                    .font(.headline)
                    .padding()
                    .frame(width: 200, height: 15)
                    .cornerRadius(8)
            }
            HStack {
                // 왼쪽 목록 - 동영상 파일만
                fileListView(
                    fileURLs: $leftFileURLs,
                    dragOver: $dragOverLeft,
                    title: "동영상 파일 (MP4, MKV)",
                    validExtensions: ["mp4", "mkv"],
                    isFirstDrop: $isFirstDropLeft
                )
                
                Divider() // 가운데 구분선
                
                // 오른쪽 목록 - 자막 파일만
                fileListView(
                    fileURLs: $rightFileURLs,
                    dragOver: $dragOverRight,
                    title: "자막 파일 (SMI, SRT, ASS)",
                    validExtensions: ["smi", "srt", "ass"],
                    isFirstDrop: $isFirstDropRight
                )
            }
            .padding()
            .frame(height: 300)
            
            HStack {
                Button(action: {
                    sortFileURLs(&leftFileURLs)
                }) {
                    Text("동영상 정렬")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    sortFileURLs(&rightFileURLs)
                }) {
                    Text("자막 정렬")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            HStack {
                Button(action: {
                    leftFileURLs.removeAll()
                    isFirstDropLeft = true
                }) {
                    Text("동영상 목록 초기화")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    rightFileURLs.removeAll()
                    isFirstDropRight = true
                }) {
                    Text("자막 목록 초기화")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            Button(action: syncFileNames) {
                Text("파일 이름 동기화")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
        .frame(width: 600)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle ?? "unknown"),
                message: Text(alertMessage ?? "unknown"),
                dismissButton: .default(Text("확인"))
            )
        }
        .padding()
    }
    
    private func openFullDiskAccessSettings() {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
    
    @ViewBuilder
    private func fileListView(fileURLs: Binding<[URL]>, dragOver: Binding<Bool>, title: String, validExtensions: [String], isFirstDrop: Binding<Bool>) -> some View {
        VStack {
            if fileURLs.wrappedValue.isEmpty {
                // 파일이 없을 때 드롭 메시지 표시
                Text("\(title)에 파일을 드롭하세요")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(dragOver.wrappedValue ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
            } else {
                // 파일 목록 표시
                List {
                    ForEach(fileURLs.wrappedValue.indices, id: \.self) { index in
                        HStack {
                            Text(fileURLs.wrappedValue[index].lastPathComponent)
                            Spacer()
                            Button(action: {
                                moveItem(in: &fileURLs.wrappedValue, at: index, direction: .up)
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                    .opacity(index > 0 ? 1 : 0.3)
                            }
                            Button(action: {
                                moveItem(in: &fileURLs.wrappedValue, at: index, direction: .down)
                            }) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.blue)
                                    .opacity(index < fileURLs.wrappedValue.count - 1 ? 1 : 0.3)
                            }
                        }
                    }
                    .onDelete { indices in
                        fileURLs.wrappedValue.remove(atOffsets: indices)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: dragOver) { providers -> Bool in
            handleFileDrop(providers: providers, fileURLs: fileURLs, validExtensions: validExtensions, isFirstDrop: isFirstDrop)
        }
    }
    
    private func moveItem(in fileURLs: inout [URL], at index: Int, direction: Direction) {
        guard index >= 0 && index < fileURLs.count else { return }
        
        let targetIndex = direction == .up ? index - 1 : index + 1
        
        if targetIndex >= 0 && targetIndex < fileURLs.count {
            fileURLs.swapAt(index, targetIndex)
        }
    }
    
    private func fetchFilesRecursively(from folderURL: URL, validExtensions: [String]) -> [URL] {
        let fileManager = FileManager.default
        var fileURLs: [URL] = []
        
        if let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                // 폴더 내 모든 파일을 검사
                if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                    fileURLs.append(fileURL)
                }
            }
        } else {
            print("폴더 탐색 실패: \(folderURL)")
        }
        
        return fileURLs
    }
    
    private func handleFileDrop(providers: [NSItemProvider], fileURLs: Binding<[URL]>, validExtensions: [String], isFirstDrop: Binding<Bool>) -> Bool {
        
        let dispatchGroup = DispatchGroup()
        
        for provider in providers {
            dispatchGroup.enter() // 작업 시작
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { dispatchGroup.leave() } // 작업 완료
                guard let data = data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                
                DispatchQueue.main.async {
                    if url.hasDirectoryPath {
                        // 폴더인 경우 재귀적으로 내부 파일 추가
                        let folderFiles = fetchFilesRecursively(from: url, validExtensions: validExtensions)
                        fileURLs.wrappedValue.append(contentsOf: folderFiles.filter { !fileURLs.wrappedValue.contains($0) })
                    } else if validExtensions.contains(url.pathExtension.lowercased()) {
                        // 파일인 경우 목록에 추가
                        if !fileURLs.wrappedValue.contains(url) {
                            fileURLs.wrappedValue.append(url)
                        }
                    }
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            // 모든 비동기 작업이 완료된 후 실행
            if isFirstDrop.wrappedValue {
                sortFileURLs(&fileURLs.wrappedValue)
                isFirstDrop.wrappedValue = false
            }
        }
        return true
    }
    
    private func sortFileURLs(_ fileURLs: inout [URL]) {
        // 자연스러운 정렬을 적용
        fileURLs.sort(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
    }
    
    private func syncFileNames() {
        guard leftFileURLs.count == rightFileURLs.count else {
            // 동영상 파일과 자막 파일의 개수가 다를 경우 경고
            alertTitle = "파일 개수 불일치"
            alertMessage = "동영상 파일과 자막 파일의 개수가 일치하지 않습니다. 동기화할 수 없습니다."
            showAlert = true
            return
        }
        
        let count = leftFileURLs.count
        let fileManager = FileManager.default
        
        for i in 0..<count {
            let videoFileURL = leftFileURLs[i]
            let subtitleFileURL = rightFileURLs[i]
            
            let videoBaseName = videoFileURL.deletingPathExtension().lastPathComponent
            let subtitleExtension = subtitleFileURL.pathExtension
            
            let newSubtitleName = "\(videoBaseName).\(subtitleExtension)"
            
            // 자막 파일의 경로와 새 파일 경로를 생성
            let subtitleDirectoryURL = subtitleFileURL.deletingLastPathComponent()
            let newSubtitleURL = subtitleDirectoryURL.appendingPathComponent(newSubtitleName)
            
            // 파일이 이동할 폴더가 존재하는지 확인하고, 없으면 생성
            do {
                if !fileManager.fileExists(atPath: subtitleDirectoryURL.path) {
                    try fileManager.createDirectory(at: subtitleDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                }
                
                try fileManager.moveItem(at: subtitleFileURL, to: newSubtitleURL)
                DispatchQueue.main.async {
                    rightFileURLs[i] = newSubtitleURL // 변경된 URL 반영
                }
            } catch {
                print("파일 이름 변경 실패: \(error.localizedDescription)")
                alertTitle = "파일 이름 변경 실패"
                alertMessage = "\(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

enum Direction {
    case up
    case down
}

#Preview {
    ContentView()
}
