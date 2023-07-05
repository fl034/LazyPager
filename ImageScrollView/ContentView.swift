//
//  ContentView.swift
//  ImageScrollView
//
//  Created by Brian Floersch on 7/2/23.
//

import SwiftUI


struct ContentView: View {
    
//    @State var data = [
//        "winter1",
//        "winter8",
//        "birthday2"
//    ]
    
    @State var data2 = Array((0...20))
    var body: some View {
        
        VStack {
            ZoomableScrollView(data: data2, index: 5) { data in
                Text("\(data)")
                    .font(.title)
//                Image(data)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
            } bottomContent: {
                Text("hi")
            }
        }
        .background(.red)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


struct ZoomableScrollView<Content: View, BottomContent: View, DataType>: UIViewRepresentable {
    private var viewLoader: (DataType) -> Content
    private var bottomContent: BottomContent
    private var data: [DataType]
    private var index: Int
    
    init(data: [DataType], index: Int, content: @escaping (DataType) -> Content, @ViewBuilder bottomContent: () -> BottomContent) {
        self.data = data
        self.index = index
        self.viewLoader = content
        self.bottomContent = bottomContent()
    }

    func makeUIView(context: Context) -> UIScrollView {
        context.coordinator.goToPage(index)
        return context.coordinator.scrollView
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(data: data,
                           startIndex: index,
                           viewLoader: viewLoader,
                           bottomController: UIHostingController(rootView: self.bottomContent))
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // set index here
        context.coordinator.goToPage(index)
//        context.coordinator.hostingController.rootView = self.content
//        assert(context.coordinator.hostingController.view.superview == uiView)
    }

    // MARK: - Coordinator

    class Coordinator: UIScrollView, UIScrollViewDelegate {
        private var viewLoader: (DataType) -> Content
        
        var data: [DataType]
        
        let preloadAmount = 1
        
        var scrollView: UIScrollView {
            return self
        }
        var loadedViews = [ZoomableView]()
        
        var contentTopToFrame: NSLayoutConstraint!
        var contentTopToContent: NSLayoutConstraint!
        var contentBottomToFrame: NSLayoutConstraint!
        
        var isFirstLoad = false

        private var internalIndex: Int = 0
        var currentIndex: Int = 0 {
            didSet {
                computeViewState()
            }
        }
        
        init(data: [DataType], startIndex: Int, viewLoader: @escaping (DataType) -> Content, bottomController: UIHostingController<BottomContent>) {
            self.data = data
            self.viewLoader = viewLoader
            currentIndex = startIndex
            super.init(frame: .zero)
            
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.backgroundColor = .gray
            scrollView.isPagingEnabled = true
            
            scrollView.layer.borderColor = CGColor.init(red: 0, green: 255, blue: 0, alpha: 1)
            scrollView.layer.borderWidth = 2
            
            scrollView.delegate = self
            computeViewState()
        }
        
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func computeViewState() {
            scrollView.delegate = nil
            DispatchQueue.main.async {
                self.scrollView.delegate = self
            }
            
            if scrollView.subviews.isEmpty {
                for i in currentIndex...(currentIndex + preloadAmount) {
                    appendView(at: i)
                }
                for i in ((currentIndex - preloadAmount)..<currentIndex).reversed() {
                    prependView(at: i)
                }
            }
            
            if let lastView = loadedViews.last {
                let diff = lastView.index - currentIndex
                if diff < (preloadAmount) {
                    for i in lastView.index..<(lastView.index + (preloadAmount - diff)) {
                        appendView(at: i + 1)
                    }
                }
            }
            
            if let firstView = loadedViews.first {
                let diff = currentIndex - firstView.index
                if diff < (preloadAmount) {
                    for i in (firstView.index - (preloadAmount - diff)..<firstView.index).reversed() {
                        prependView(at: i)
                    }
                }
            }
            self.removeOutOfFrameViews()
            print(self.loadedViews.map { $0.index })
        }
        
        func removeOutOfFrameViews() {
            for view in loadedViews {
                if abs(currentIndex - view.index) > preloadAmount {
                    remove(view: view)
                }
            }
        }
        
        func remove(view: ZoomableView) {
            let index = view.index
            loadedViews.removeAll { $0.index == view.index }
            view.removeFromSuperview()
            
            if let firstView = loadedViews.first {
                firstView.leadingConstraint?.isActive = false
                firstView.leadingConstraint = nil
                firstView.leadingConstraint = firstView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
                firstView.leadingConstraint?.isActive = true
                
                if firstView.index > index {
                    scrollView.contentOffset.x -= scrollView.frame.size.width
                    internalIndex -= 1
                }
            }
            
            if let lastView = loadedViews.last {
                lastView.trailingConstraint?.isActive = false
                lastView.trailingConstraint = nil
                lastView.trailingConstraint = lastView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor)
                lastView.trailingConstraint?.isActive = true
            }
        }
        
        func loadView(at index: Int) -> ZoomableView? {
            guard let dta = data[safe: index] else {
                return nil
            }
            
            let loadedContent = UIHostingController(rootView: viewLoader(dta)).view!
            
            loadedContent.translatesAutoresizingMaskIntoConstraints = false
            loadedContent.backgroundColor = .clear
            
            return ZoomableView(view: loadedContent, index: index)
        }
        
        func addSubview(_ zoomView: ZoomableView) {
            scrollView.addSubview(zoomView)
            NSLayoutConstraint.activate([
                zoomView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
                zoomView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            ])
        }
        
        func addFirstView(_ zoomView: ZoomableView) {
            zoomView.leadingConstraint = zoomView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
            zoomView.trailingConstraint = zoomView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor)
            zoomView.leadingConstraint?.isActive = true
            zoomView.trailingConstraint?.isActive = true
        }
        
        func appendView(at index: Int) {
            guard let zoomView = loadView(at: index) else {
                return
            }
            
            addSubview(zoomView)
            
            if let lastView = loadedViews.last {
                lastView.trailingConstraint?.isActive = false
                lastView.trailingConstraint = nil
                
                zoomView.leadingConstraint = zoomView.leadingAnchor.constraint(equalTo: lastView.trailingAnchor)
                zoomView.trailingConstraint = zoomView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor)
                zoomView.leadingConstraint?.isActive = true
                zoomView.trailingConstraint?.isActive = true
                
            } else {
                addFirstView(zoomView)
            }
            loadedViews.append(zoomView)
        }
        
        func prependView(at index: Int) {
            guard let zoomView = loadView(at: index) else {
                return
            }
            
            addSubview(zoomView)
            
            if let firstView = loadedViews.first {
                firstView.leadingConstraint?.isActive = false
                firstView.leadingConstraint = nil
                
                zoomView.leadingConstraint = zoomView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor)
                zoomView.trailingConstraint = zoomView.trailingAnchor.constraint(equalTo: firstView.leadingAnchor)
                zoomView.leadingConstraint?.isActive = true
                zoomView.trailingConstraint?.isActive = true
                
            } else {
                addFirstView(zoomView)
            }
            
            scrollView.contentOffset.x += scrollView.frame.size.width
            internalIndex += 1
            loadedViews.insert(zoomView, at: 0)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let visible = loadedViews.first { isSubviewVisible($0, in: scrollView) }
            let newIndex = loadedViews.firstIndex(where: { $0.index == visible?.index })!
            if newIndex != internalIndex {
                currentIndex = visible!.index
                internalIndex = newIndex
            }
        }
        
        func isSubviewVisible(_ subview: UIView, in scrollView: UIScrollView) -> Bool {
            let visibleRect = CGRect(origin: scrollView.contentOffset, size: scrollView.bounds.size)
            let subviewFrame = scrollView.convert(subview.frame, from: subview.superview)
            let intersectionRect = visibleRect.intersection(subviewFrame)
            return !intersectionRect.isNull && intersectionRect.size.height > 0 && intersectionRect.size.width > 0
        }
        
        func goToPage(_ page: Int) {
            guard let index = loadedViews.firstIndex(where: { $0.index == page }) else {
                return
            }
            scrollView.contentOffset.x = CGFloat(index) * scrollView.frame.size.width
            internalIndex = index
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            if !isFirstLoad {
                goToPage(currentIndex)
                isFirstLoad = true
            }
        }
        
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
