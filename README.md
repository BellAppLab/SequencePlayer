# Player

Play a series of media files in sequence with no lags on iOS.

_v0.1.0_

## Usage

```swift
class ViewController: UIViewController, SequencePlayerDataSource, SequencePlayerDelegate {

    var player: SequencePlayer!

    lazy var urls: [URL] = {
        ...
    }()

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
        
    }

    //MARK: Player Data Source
    func numberOfItemsInSequencePlayer(_ player: SequencePlayer) -> Int {
        return self.urls.count
    }

    func sequencePlayer(_ player: SequencePlayer, itemURLAtIndex index: Int) -> URL {
        return self.urls[index]
    }

    //Use this is your dealing with videos
    
    @IBOutlet weak var playerView: SequencePlayerView!

    func sequencePlayerView(forSequencePlayer player: SequencePlayer) -> SequencePlayerView {
        return self.playerView
    }
}
```

## Requirements

* iOS 8+
* Swift 3.0

## Installation

### Cocoapods

Because of [this](http://stackoverflow.com/questions/39637123/cocoapods-app-xcworkspace-does-not-exists), I've dropped support for Cocoapods on this repo. I cannot have production code rely on a dependency manager that breaks this badly. 

### Git Submodules

**Why submodules, you ask?**

Following [this thread](http://stackoverflow.com/questions/31080284/adding-several-pods-increases-ios-app-launch-time-by-10-seconds#31573908) and other similar to it, and given that Cocoapods only works with Swift by adding the use_frameworks! directive, there's a strong case for not bloating the app up with too many frameworks. Although git submodules are a bit trickier to work with, the burden of adding dependencies should weigh on the developer, not on the user. :wink:

To install Keyboard using git submodules:

```
cd toYourProjectsFolder
git submodule add -b submodule --name SequencePlayer https://github.com/BellAppLab/SequencePlayer.git
```

Then, navigate to the new SequencePlayer folder and drag the `Source` folder into your Xcode project.

## Author

Bell App Lab, apps@bellapplab.com

## License

Player is available under the MIT license. See the LICENSE file for more info.
