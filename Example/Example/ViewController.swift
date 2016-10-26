//
//  ViewController.swift
//  Example
//
//  Created by André Abou Chami Campana on 21/10/2016.
//  Copyright © 2016 Bell App Lab. All rights reserved.
//

import UIKit
import AVFoundation


class ViewController: UIViewController, SequencePlayerDataSource, SequencePlayerDelegate {
    
    var player: SequencePlayer!
    
    lazy var urls: [URL] = {
        var result = [URL]()
        ["http://az764616.vo.msecnd.net/videos/269_j1.mp4",
         "http://az764616.vo.msecnd.net/videos/269_c1.mp4",
         "http://az764616.vo.msecnd.net/videos/269_g1.mp4",
         "http://az764616.vo.msecnd.net/videos/269_c2.mp4",
         "http://az764616.vo.msecnd.net/videos/269_g2.mp4"].forEach
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




