import UIKit
import AVFoundation


//MARK: Consts
private var playerContext = 0


//MARK: - Delegate and Data Source
protocol PlayerDelegate: class {
    func playerStateDidChange(_ player: Player)
    func playerDidEnd(_ player: Player)
}


@objc protocol PlayerDataSource: class {
    func numberOfItemsInPlayer(_ player: Player) -> Int
    func player(_ player: Player, itemURLAtIndex index: Int) -> URL
    @objc optional func playerView(forPlayer player: Player) -> PlayerView
}


//MARK: - Player Controls
//MARK: -
extension Player
{
    func play(atIndex index: Int? = nil) {
        guard self.state != .playing else { return }
        
        var didChangeIndex = false
        
        if let i = index {
            guard i > -1 && i < self.dataSource.numberOfItemsInPlayer(self) else {
                fatalError("Player index out of bounds... Index: \(index)")
            }
            self.currentIndex = i
            didChangeIndex = true
        } else {
            if self.currentIndex == NSNotFound {
                self.currentIndex = 0
                didChangeIndex = true
            }
        }
        
        if self.player == nil {
            self.player = AVQueuePlayer()
        }
        
        self.dataSource.playerView?(forPlayer: self).player = self.player
        
        if didChangeIndex {
            self.player?.pause()
        }
        
        if let _ = self.player?.currentItem {
            self.player?.play()
            self.state = .playing
            return
        }
        
        self.prefetch()
    }
    
    func pause() {
        self.player?.pause()
        self.state = .paused
    }
    
    func next() {
        guard self.dataSource.numberOfItemsInPlayer(self) > self.currentIndex + 1 else { self.reload(); return }
        self.play(atIndex: self.currentIndex + 1)
    }
    
    func previous() {
        guard self.currentIndex - 1 > -1 else { self.reload(); return }
        self.play(atIndex: self.currentIndex - 1)
    }
    
    fileprivate func resumePlayback() {
        if state != .playing {
//            self.isProgressTimerActive = true
            self.play()
        }
    }
}


//MARK: - Main Implementation
//MARK: -
class Player: NSObject
{
    //MARK:
    enum State: Int, CustomStringConvertible
    {
        case ready = 0
        case playing
        case paused
        case loading
        case failed
        
        var description: String {
            get{
                switch self
                {
                case .ready:
                    return "Ready"
                case .playing:
                    return "Playing"
                case .failed:
                    return "Failed"
                case .paused:
                    return "Paused"
                case .loading:
                    return "Loading"
                    
                }
            }
        }
    }
    
    fileprivate(set) var state: State = .ready {
        didSet {
            guard state != oldValue else { return }
            
            switch state {
            case .failed, .ready:
                self.isBackgroundTaskActive = false
                self.isAudioSessionActive = false
            default:
                self.isBackgroundTaskActive = true
                self.isAudioSessionActive = true
            }
            self.delegate?.playerStateDidChange(self)
        }
    }
    
    //MARK: - Setup
    static var cacheAge: TimeInterval = 3600 * 24 * 7
    static var numberOfItemsToPrefetch = 3
    
    deinit{
        self.pause()
        self.currentIndex = NSNotFound
        self.isAudioSessionActive = false
//        self.isProgressTimerActive = false
        self.isBackgroundTaskActive = false
        NotificationCenter.default.removeObserver(self)
        self.playerItems.forEach { (item) in
            item.removeObserver(self,
                                forKeyPath: #keyPath(AVPlayerItem.status),
                                context: &playerContext)
        }
    }
    
    init(withDataSource dataSource: PlayerDataSource, andDelegate delegate: PlayerDelegate? = nil) {
        self.dataSource = dataSource
        self.delegate = delegate
    }
    
    private(set) weak var dataSource: PlayerDataSource!
    private(set) weak var delegate: PlayerDelegate?
    
    fileprivate var hasSetUp = false
    
    func reload() {
        self.pause()
        self.state = .ready
        self.currentIndex = NSNotFound
        self.isAudioSessionActive = false
//        self.isProgressTimerActive = false
        self.isBackgroundTaskActive = false
        NotificationCenter.default.removeObserver(self)
        self.playerItems.forEach { (item) in
            item.removeObserver(self,
                                forKeyPath: #keyPath(AVPlayerItem.status),
                                context: &playerContext)
        }
        self.playerItems = []
        self.player?.removeAllItems()
        self.currentlyDownloadingURLs = []
    }
    
    //MARK: - Playing
    fileprivate var player: AVQueuePlayer?
    
    var items: [AVPlayerItem]? {
        return self.player?.items()
    }
    
    var currentItem: AVPlayerItem? {
        return self.player?.currentItem
    }
    
    fileprivate(set) var currentIndex: Int = NSNotFound {
        didSet {
            guard currentIndex != oldValue && currentIndex != NSNotFound else { return }
            
            func shouldStartLoading() -> Bool {
                if oldValue == NSNotFound {
                    return true
                }
                return abs(currentIndex - oldValue) >= Player.numberOfItemsToPrefetch
            }
            
            if shouldStartLoading() {
                self.state = .loading
            }
        }
    }
    
    var volume: Float {
        get {
            return self.player?.volume ?? 0
        }
        set {
            self.player?.volume = newValue
        }
    }
    
    //MARK: Progress
//    private var progressObserver: AnyObject!
//    
//    fileprivate var isProgressTimerActive: Bool = false {
//        didSet {
//            guard isProgressTimerActive != oldValue else { return }
//            
//            if isProgressTimerActive {
//                guard let currentItem = self.currentItem, currentItem.duration.isValid == true else { return }
//                self.progressObserver = self.player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.05, Int32(NSEC_PER_SEC)),
//                                                                             queue: nil)
//                { [weak self] (time : CMTime) -> Void in
//                    self?.timerAction(withTime: time)
//                } as AnyObject!
//            } else {
//                guard let player = self.player, let observer = self.progressObserver else { return }
//                player.removeTimeObserver(observer)
//                self.progressObserver = nil
//            }
//        }
//    }
    
    //MARK: - Background Task Id
    private var backgroundTaskId = UIBackgroundTaskInvalid
    
    fileprivate var isBackgroundTaskActive: Bool = false {
        didSet {
            guard (self.backgroundTaskId == UIBackgroundTaskInvalid && isBackgroundTaskActive) || (self.backgroundTaskId != UIBackgroundTaskInvalid && !isBackgroundTaskActive) else { return }
            
            guard isBackgroundTaskActive != oldValue else { return }
            
            if isBackgroundTaskActive {
                self.backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] _ in
                    guard let identifier = self?.backgroundTaskId else { return }
                    UIApplication.shared.endBackgroundTask(identifier)
                    self?.backgroundTaskId = UIBackgroundTaskInvalid
                }
            } else {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                self.backgroundTaskId = UIBackgroundTaskInvalid
            }
        }
    }
    
    //MARK: - Audio Session
    fileprivate var isAudioSessionActive: Bool = false {
        didSet {
            guard isAudioSessionActive != oldValue else { return }
            
            if isAudioSessionActive {
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(handleStall),
                                                       name: NSNotification.Name.AVPlayerItemPlaybackStalled,
                                                       object: nil)
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(handleAudioSessionInterruption),
                                                       name: NSNotification.Name.AVAudioSessionInterruption,
                                                       object: AVAudioSession.sharedInstance())
                
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                    try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeDefault)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Audio Session Activation Error: \(error)")
                }
            } else {
                NotificationCenter.default.removeObserver(self,
                                                          name: NSNotification.Name.AVPlayerItemPlaybackStalled,
                                                          object: nil)
                NotificationCenter.default.removeObserver(self,
                                                          name: NSNotification.Name.AVAudioSessionInterruption,
                                                          object: AVAudioSession.sharedInstance())
                
                do {
                    try AVAudioSession.sharedInstance().setActive(false)
                } catch {
                    print("Audio Session Deactivation Error: \(error)")
                }
            }
        }
    }
    
    @objc private func handleStall() {
        self.player?.pause()
        self.player?.play()
    }
    
//    private func timerAction(withTime time: CMTime) {
//        guard self.currentItem != nil else { return }
//        self.delegate?.player(self,
//                              progressDidChangeWithTime: time)
//    }
    
    @objc private func handleAudioSessionInterruption(_ notification : Notification) {
        guard let userInfo = notification.userInfo as? [String: AnyObject] else { return }
        guard let rawInterruptionType = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber else { return }
        guard let interruptionType = AVAudioSessionInterruptionType(rawValue: rawInterruptionType.uintValue) else { return }
        
        switch interruptionType {
        case .began: //interruption started
            self.player?.pause()
        case .ended: //interruption ended
            if let rawInterruptionOption = userInfo[AVAudioSessionInterruptionOptionKey] as? NSNumber {
                let interruptionOption = AVAudioSessionInterruptionOptions(rawValue: rawInterruptionOption.uintValue)
                if interruptionOption == AVAudioSessionInterruptionOptions.shouldResume {
                    self.resumePlayback()
                }
            }
        }
    }
    
    //MARK: - Downloading
    fileprivate lazy var downloadQueue: OperationQueue = {
        let result = OperationQueue()
        result.name = "PlayerQueue"
        result.maxConcurrentOperationCount = 1
        return result
    }()
    
    fileprivate lazy var fileQueue: OperationQueue = {
        let result = OperationQueue()
        result.name = "PlayerFileQueue"
        result.maxConcurrentOperationCount = 1
        return result
    }()

    
    fileprivate(set) lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "Player")
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.networkServiceType = .video
        let result = URLSession(configuration: configuration,
                                delegate: self,
                                delegateQueue: self.downloadQueue)
        return result
    }()
    
    fileprivate lazy var currentlyDownloadingURLs = [URL]()
    
    //MARK: - KVO
    fileprivate lazy var playerItems = [AVPlayerItem]()
    
    @objc fileprivate func itemDidPlayToEnd(_ notification: Notification) {
        guard self.currentIndex + 1 < self.dataSource.numberOfItemsInPlayer(self) else {
            self.delegate?.playerDidEnd(self)
            self.reload()
            return
        }
        self.currentIndex += 1
        self.prefetch()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItemStatus
            
            // Get the status change from the change dictionary
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over the status
            switch status {
            case .readyToPlay:
            // Player item is ready to play.
                if self.state != .playing {
                    self.player?.play()
                    self.state = .playing
                }
            case .failed:
                if self.state == .playing {
                    self.pause()
                }
            case .unknown:
                // Player item is not yet ready.
                break
            }
        }
    }
}


//MARK: - Downloading
//MARK: -
fileprivate extension Player
{
    var documentsURL: URL? {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.bellapplab"
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last?.appendingPathComponent("\(bundleId).Player").standardizedFileURL
    }
    
    func prefetch() {
        guard self.currentIndex != NSNotFound else { fatalError("Player: We need to set the current index before prefetching!") }
        guard let documentsURL = self.documentsURL, let dataSource = self.dataSource else { return }
        let currentIndex = self.currentIndex
        let total = self.dataSource.numberOfItemsInPlayer(self)
        let manager = FileManager.default
        
        func setUpCacheFolder() {
            guard !self.hasSetUp else { return }
            
            if !manager.fileExists(atPath: documentsURL.path) {
                do {
                    try manager.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    fatalError("Player couldn't not create its root folder... \(error)")
                }
            }
            
            do {
                let files = try manager.contentsOfDirectory(at: documentsURL,
                                                            includingPropertiesForKeys: [.contentAccessDateKey],
                                                            options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants, .skipsHiddenFiles])
                let cacheDate = Date(timeIntervalSinceNow: -1 * Player.cacheAge)
                for file in files {
                    if let date = try file.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate {
                        if date.timeIntervalSince(cacheDate) <= 0 {
                            try manager.removeItem(at: file)
                        }
                    }
                }
            } catch {
                fatalError("Player: Something went wrong while enumerating files... \(error)")
            }
            
            self.hasSetUp = true
        }
        
        func isAlreadyDownloading(_ remoteURL: URL) -> Bool {
            for url in self.currentlyDownloadingURLs {
                if url == remoteURL {
                    return true
                }
            }
            return false
        }
        
        func isAlreadyInPlayer(_ localURL: URL) -> Bool {
            guard let player = self.player else { return false }
            for item in player.items() {
                if let asset = item.asset as? AVURLAsset {
                    if asset.url == localURL {
                        return true
                    }
                }
            }
            return false
        }
        
        self.fileQueue.addOperation { [weak self] _ in
            setUpCacheFolder()
            
            var i = 0
            var operations = [Operation]()
            
            while i < Player.numberOfItemsToPrefetch && currentIndex + i < total {
                let remoteURL = dataSource.player(self!, itemURLAtIndex: currentIndex + i)
                let localURL = documentsURL.appendingPathComponent(remoteURL.lastPathComponent)
                
                if !isAlreadyDownloading(remoteURL) && !manager.fileExists(atPath: localURL.path) {
                    self?.currentlyDownloadingURLs.append(remoteURL)
                    let task = self?.urlSession.downloadTask(with: remoteURL)
                    operations.append(BlockOperation(block: {
                        task?.resume()
                    }))
                } else if !isAlreadyInPlayer(localURL) {
                    self?.didFinishDownloadingFile(toURL: localURL)
                }
                
                i += 1
            }
            
            self?.downloadQueue.addOperations(operations, waitUntilFinished: false)
        }
    }
    
    func didFinishDownloadingFile(toURL url: URL) {
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        self.playerItems.append(item)
        self.player?.insert(item, after: nil)
        item.addObserver(self,
                         forKeyPath: #keyPath(AVPlayerItem.status),
                         options: [.new],
                         context: &playerContext)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(Player.itemDidPlayToEnd(_:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: item)
    }
}

//MARK: URL Session Data Delegate
extension Player: URLSessionDataDelegate, URLSessionDownloadDelegate
{
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        guard let response = proposedResponse.response as? HTTPURLResponse, let url = response.url, var headers = response.allHeaderFields as? [String: String] else { return }
        
        var cachedResponse: CachedURLResponse
        if response.allHeaderFields["Cache-Control"] == nil {
            headers["Cache-Control"] = "max-age=604800"
            
            if let newResponse = HTTPURLResponse(url: url,
                                              statusCode: response.statusCode,
                                              httpVersion: "HTTP/1.1",
                                              headerFields: headers)
            {
                cachedResponse = CachedURLResponse(response: newResponse,
                                                   data: proposedResponse.data,
                                                   userInfo: proposedResponse.userInfo,
                                                   storagePolicy: proposedResponse.storagePolicy)
            } else {
                cachedResponse = proposedResponse
            }
        } else {
            cachedResponse = proposedResponse
        }
        
        completionHandler(cachedResponse)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let data = try? Data(contentsOf: location), let documentsURL = self.documentsURL, let fileName = downloadTask.originalRequest?.url?.lastPathComponent else { return }
        
        print("Did finish downloading item \(fileName)")
        
        let manager = FileManager.default
        
        let finalURL = documentsURL.appendingPathComponent(fileName)
        
        manager.createFile(atPath: finalURL.path, contents: data, attributes: nil)
        
        for (index, existingURL) in self.currentlyDownloadingURLs.enumerated() {
            if finalURL == existingURL {
                self.currentlyDownloadingURLs.remove(at: index)
            }
        }
        
        DispatchQueue.main.async { [weak self] _ in
            self?.didFinishDownloadingFile(toURL: finalURL)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            dLog("Player Download error: \(error)")
        }
    }
}


//MARK: - Player View
//MARK: -
class PlayerView: UIView
{
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    // Override UIView property
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}


//MARK: - Aux
//MARK: -
public func dLog(_ message: @autoclosure () -> String, filename: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
        debugPrint("[\(URL(string: filename)?.lastPathComponent):\(line)]", "\(function)", message(), separator: " - ")
    #else
    #endif
}
