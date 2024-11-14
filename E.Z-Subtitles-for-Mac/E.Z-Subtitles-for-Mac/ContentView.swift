import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var leftFileNames: [String] = []  // 왼쪽 목록의 파일 이름
    @State private var rightFileNames: [String] = [] // 오른쪽 목록의 파일 이름
    @State private var dragOverLeft = false         // 왼쪽 드래그 상태
    @State private var dragOverRight = false        // 오른쪽 드래그 상태

    var body: some View {
        HStack {
            // 왼쪽 목록
            fileListView(
                fileNames: $leftFileNames,
                dragOver: $dragOverLeft,
                title: "왼쪽 리스트"
            )
            
            Divider() // 가운데 구분선
            
            // 오른쪽 목록
            fileListView(
                fileNames: $rightFileNames,
                dragOver: $dragOverRight,
                title: "오른쪽 리스트"
            )
        }
        .padding()
        .frame(width: 600, height: 300)
    }

    @ViewBuilder
    private func fileListView(fileNames: Binding<[String]>, dragOver: Binding<Bool>, title: String) -> some View {
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
            handleFileDrop(providers: providers, fileNames: fileNames)
        }
    }

    private func handleFileDrop(providers: [NSItemProvider], fileNames: Binding<[String]>) -> Bool {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data = data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                let validExtensions = ["smi", "srt", "ass", "png"] // 허용되는 확장자 목록
                if validExtensions.contains(url.pathExtension.lowercased()) {
                    DispatchQueue.main.async {
                        if !fileNames.wrappedValue.contains(url.lastPathComponent) {
                            fileNames.wrappedValue.append(url.lastPathComponent)
                        }
                    }
                }
            }
        }
        return true
    }
}

#Preview {
    ContentView()
}
