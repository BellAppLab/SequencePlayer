//
//  ViewController.swift
//  Example
//
//  Created by André Abou Chami Campana on 21/10/2016.
//  Copyright © 2016 Bell App Lab. All rights reserved.
//

import UIKit
import AVFoundation


class ViewController: UIViewController, PlayerDataSource, PlayerDelegate {
    
    var player: Player!
    
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
    
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var spinningThing: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.player = Player(withDataSource: self,
                             andDelegate: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.player.play()
    }
    
    //MARK: Player Delegate
    func playerStateDidChange(_ player: Player) {
        switch player.state {
        case .loading:
            self.spinningThing.startAnimating()
        default:
            self.spinningThing.stopAnimating()
        }
    }
    
    func playerDidEnd(_ player: Player) {
        //Noop
    }
    
    //MARK: Player Data Source
    func numberOfItemsInPlayer(_ player: Player) -> Int {
        return self.urls.count
    }
    
    func player(_ player: Player, itemURLAtIndex index: Int) -> URL {
        return self.urls[index]
    }
    
    func playerView(forPlayer player: Player) -> PlayerView {
        return self.playerView
    }
}




