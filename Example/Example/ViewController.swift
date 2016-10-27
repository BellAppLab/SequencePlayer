import UIKit


class ViewController: UIViewController, SequencePlayerDataSource, SequencePlayerDelegate {
    
    var player: SequencePlayer!
    
    lazy var urls: [URL] = {
        var result = [URL]()
        ["http://media0.giphy.com/media/Wqhdoubttqizu/giphy.mp4",
         "http://media0.giphy.com/media/3UvKSHiEspIKQ/200w.mp4",
         "http://media0.giphy.com/media/mfmLlxkQn6eTS/200.mp4"].forEach
        { string in
            if let url = URL(string: string) {
                result.append(url)
            }
        }
        return result
    }()
    
    @IBOutlet weak var playerView: SequencePlayerView!
    @IBOutlet weak var spinningThing: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.player = SequencePlayer(withDataSource: self,
                                     andDelegate: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.player.play()
    }
    
    //MARK: Player Delegate
    func sequencePlayerStateDidChange(_ player: SequencePlayer) {
        switch player.state {
        case .loading:
            self.spinningThing.startAnimating()
        default:
            self.spinningThing.stopAnimating()
        }
    }
    
    func sequencePlayerDidEnd(_ player: SequencePlayer) {
        //Noop
    }
    
    //MARK: Player Data Source
    func numberOfItemsInSequencePlayer(_ player: SequencePlayer) -> Int {
        return self.urls.count
    }
    
    func sequencePlayer(_ player: SequencePlayer, itemURLAtIndex index: Int) -> URL {
        return self.urls[index]
    }
    
    func sequencePlayerView(forSequencePlayer player: SequencePlayer) -> SequencePlayerView {
        return self.playerView
    }
}




