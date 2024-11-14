import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var leftFileNames: [String] = []  // 동영상 파일 이름
    @State private var rightFileNames: [String] = [] // 자막 파일 이름
    @State private var leftFileNamesWithURL: [URL] = []  // 동영상 파일 이름
    @State private var rightFileNamesWithURL: [URL] = [] // 자막 파일 이름
    @State private var dragOverLeft = false         // 왼쪽 드래그 상태
    @State private var dragOverRight = false        // 오른쪽 드래그 상태
    @State private var showAlert = false            // 경고 메시지 표시 여부

    var body: some View {
        VStack {
            HStack {
                // 왼쪽 목록 - 동영상 파일만
                fileListView(
                    fileNames: $leftFileNames,
                    fileNamesWithURL: $leftFileNamesWithURL,
                    dragOver: $dragOverLeft,
                    title: "동영상 파일 (MP4, MKV)",
                    validExtensions: ["mp4", "mkv"]
                )
                
                Divider() // 가운데 구분선
                
                // 오른쪽 목록 - 자막 파일만
                fileListView(
                    fileNames: $rightFileNames,
                    fileNamesWithURL: $rightFileNamesWithURL,
                    dragOver: $dragOverRight,
                    title: "자막 파일 (SMI, SRT, ASS)",
                    validExtensions: ["smi", "srt", "ass"]
                )
            }
            .padding()
            .frame(height: 300)

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
                title: Text("파일 개수 불일치"),
                message: Text("동영상 파일과 자막 파일의 개수가 일치하지 않습니다. 동기화할 수 없습니다."),
                dismissButton: .default(Text("확인"))
            )
        }
    }

    @ViewBuilder
    private func fileListView(fileNames: Binding<[String]>,fileNamesWithURL: Binding<[URL]>, dragOver: Binding<Bool>, title: String, validExtensions: [String]) -> some View {
        VStack {
            if fileNames.wrappedValue.isEmpty {
                // 파일이 없을 때 드롭 메시지 표시
                Text("\(title)에 파일을 드롭하세요")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(dragOver.wrappedValue ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
            } else {
                // 파일 목록 표시
                List(fileNames.wrappedValue, id: \.self) { name in
                    Text(name)
                }
                .listStyle(PlainListStyle())
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: dragOver) { providers -> Bool in
            handleFileDrop(providers: providers, fileNames: fileNames, fileNamesWithURL: fileNamesWithURL, validExtensions: validExtensions)
        }
    }

    private func handleFileDrop(providers: [NSItemProvider], fileNames: Binding<[String]>, fileNamesWithURL: Binding<[URL]>, validExtensions: [String]) -> Bool {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data = data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                print(url.lastPathComponent)
                // 허용된 확장자인지 확인
                if validExtensions.contains(url.pathExtension.lowercased()) {
                    DispatchQueue.main.async {
                        if !fileNames.wrappedValue.contains(url.lastPathComponent) {
                            fileNames.wrappedValue.append(url.lastPathComponent)
                            fileNamesWithURL.wrappedValue.append(url)
                        }
                    }
                }
            }
        }
        return true
    }

    private func syncFileNames() {
        guard leftFileNames.count == rightFileNames.count else {
            // 동영상 파일과 자막 파일의 개수가 다를 경우 경고
            showAlert = true
            return
        }
        
        // 동영상 파일과 자막 파일이 개수가 같을 경우, 이름 동기화
        let count = leftFileNames.count
        
        for i in 0..<count {
            let videoFile = leftFileNamesWithURL[i]
            let subtitleFile = rightFileNamesWithURL[i]
            
            let videoBaseName = videoFile.deletingPathExtension().lastPathComponent
            let subtitleExtension = subtitleFile.pathExtension
            
            let newSubtitleName = "\(videoBaseName).\(subtitleExtension)"
            
            // 실제 파일 이름 변경
            let fileManager = FileManager.default
            let subtitleURL = subtitleFile
            let newSubtitleURL = subtitleURL.deletingLastPathComponent().appendingPathComponent(newSubtitleName)
            
            do {
                try fileManager.moveItem(at: subtitleURL, to: newSubtitleURL)
                DispatchQueue.main.async {
                    rightFileNames[i] = newSubtitleName // 변경된 이름 반영
                }
            } catch {
                print("파일 이름 변경 실패: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}
