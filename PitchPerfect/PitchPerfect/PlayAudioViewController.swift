//
//  PlayAudioViewController.swift
//  PitchPerfect
//
//  Play recorded audio from previous controller at faster or slower rate
//  or higher or lower pitch with the ability to pause and continue.
//  The pause/stop button will disappear when finishing playing.
//  You can also use the slider to control the volume.
//  Note: As you slide the volume, the chipmunk and dathvader does not change volume
//        since the audio is converted before playing and audioPlayerNode.volume does not work the way I wanted
//        This is something we can investigate later.
//
//  Created by Jeffrey Zhang on 3/6/15.
//  Copyright (c) 2015 JHZ. All rights reserved.
//
// reference: http://www.apeth.com/iOSBook/ch27.html
//            http://iosapi.xamarin.com/?link=C%3aAVFoundation.AVAudioPlayerNode.AVAudioPlayerNode(System.IntPtr)
//            http://hondrouthoughts.blogspot.com/2014/09/more-avaudioplayernode-with-swift-and.html
//            http://sandmemory.blogspot.com/2014/12/how-would-you-add-reverbecho-to-audio.html
//
// known issue:
//       since the callback function is delayed,


import UIKit
import AVFoundation


class PlayAudioViewController: UIViewController, AVAudioPlayerDelegate {
  //which audio play action is active
    enum  PlayChoices {
        case Block_snail
        case Block_rabbit
        case Block_chipmunk
        case Block_dathvader
        case Block_echo
        case Block_reverb
        case Block_none
    }

    
 
    // constraints to arrange/position all buttons
    @IBOutlet weak var ReverbX: NSLayoutConstraint!
    @IBOutlet weak var ReverbY: NSLayoutConstraint!
    @IBOutlet weak var EchoX: NSLayoutConstraint!
    @IBOutlet weak var EchoY: NSLayoutConstraint!
    @IBOutlet weak var gap2Btn: NSLayoutConstraint!
    @IBOutlet weak var RealStopY: NSLayoutConstraint!
    @IBOutlet weak var chipmunkPos: NSLayoutConstraint!
    @IBOutlet weak var rightlow: NSLayoutConstraint!
    @IBOutlet weak var topright: NSLayoutConstraint!
    @IBOutlet weak var lowleft: NSLayoutConstraint!
    @IBOutlet weak var RabbitPosY: NSLayoutConstraint!    //from top
    @IBOutlet weak var chipmunkPosY: NSLayoutConstraint!  //from top
    @IBOutlet weak var GapHeight: NSLayoutConstraint!
    @IBOutlet weak var DathY: NSLayoutConstraint!
    @IBOutlet weak var stoppauseY: NSLayoutConstraint!  // from bottom
    
    
    
    @IBOutlet weak var maxVolX: NSLayoutConstraint!
    @IBOutlet weak var maxVolY: NSLayoutConstraint!
    @IBOutlet weak var muteVolX: NSLayoutConstraint!
    @IBOutlet weak var muteVolY: NSLayoutConstraint!
    @IBOutlet weak var sliderRightX: NSLayoutConstraint!
    @IBOutlet weak var sliderLeftX: NSLayoutConstraint!
    @IBOutlet weak var sliderY: NSLayoutConstraint!
    
    //image button ( for  getting image size)
    @IBOutlet weak var chipmunk: UIButton!
    @IBOutlet weak var echo: UIButton!
    @IBOutlet weak var stopOrpause: UIButton!
    @IBOutlet weak var realStop: UIButton!
    @IBOutlet weak var reverb: UIButton!
    @IBOutlet weak var volControl: UISlider!
    
 
    var audioPlayer: AVAudioPlayer!

    var audioData : RecordedAudio!
    var audioEngine: AVAudioEngine = AVAudioEngine()
    var audioFile: AVAudioFile!
    var audioPlayerNode: AVAudioPlayerNode!
    
    //2nd player for echo use
    var audioPlayer2: AVAudioPlayer!
    
    // array is for reverb purpose
    var reverbPlayers:[AVAudioPlayer] = []
    let N:Int = 10
    
    
    //we can change image
    let pauseImg =  UIImage(named: "pause")
    let playImg =  UIImage(named: "play")
    let stopImg =  UIImage(named: "stop")
    let delay:NSTimeInterval = 0.02   //20 ms delay

    var activePlayer  = PlayChoices.Block_none
    var AVcurrentTime: NSTimeInterval!
    
    var isPaused = 0
    
    //Hide btn and deativate audio session after finished playing
    //pay attention to multiple players
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        if(flag)
        {
            // in echo case...the first player will invalidate the session??
            // similarly reverb....N players
            // we need stop the seesion when the last player finishing playing
            var OK2Close: Bool = false
            switch(activePlayer){
                case PlayChoices.Block_snail, PlayChoices.Block_rabbit:
                    OK2Close = true
                case PlayChoices.Block_echo:
                    if(player == audioPlayer2)
                    {
                        OK2Close=true
                    }
                case PlayChoices.Block_reverb:
                    if( player ==  reverbPlayers[N-1])
                    {
                        OK2Close = true
                    }
                default:
                    OK2Close = true
            }
            if(OK2Close)
            {
                AVAudioSession.sharedInstance().setActive(false, error: nil)
                stopOrpause.hidden = true
                realStop.hidden = true
            }
         }
        else
        {
            println("error in audioPlayerDidFinishPlaying")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
 
        stopOrpause.hidden = true
        realStop.hidden = true
        
        //any model data from prev controller
        if( audioData != nil){
            audioPlayer = AVAudioPlayer(contentsOfURL: audioData.filePathUrl, error: nil)
            audioPlayer.enableRate = true
            audioPlayer.rate = 1.0
            audioPlayer.delegate = self
            
            audioFile = AVAudioFile(forReading: audioData.filePathUrl, error: nil)
            //audiosamplerate = audioFile.fileFormat.sampleRate
            //var totalLength = audioFile.length
            
            //prepare 2nd player for echo
             audioPlayer2 = AVAudioPlayer(contentsOfURL: audioData.filePathUrl, error: nil)
            
            //prepare reverb players
            for i in 0...N {
                var temp = AVAudioPlayer(contentsOfURL: audioData.filePathUrl, error: nil)
                reverbPlayers.append(temp)
            }
            // no selection for which audio style to play yet
            activePlayer  = PlayChoices.Block_none
            
            //set initial volume
            volControl.value = 0.5
            
            audioPlayer.volume = volControl.value
            audioPlayer2.volume = volControl.value
            
             //set AudioSsion policy once
            setSessionPlayer()

        }else{
            println("Should never be here since no sound to play!")
        }
    }
    
    // lessons learned: it is frutile to set position before rendering
    // i.e do not do it in  viewWillAppear
    // size will change....as you will see when you click on chipmunk
    // so move code to viewDidLayoutSubviews
  

    override func viewDidLayoutSubviews() {
        
        let scrWidth = UIScreen.mainScreen().bounds.width
        let scrHight = UIScreen.mainScreen().bounds.height
        
        let btnWidth = chipmunk.imageView?.frame.width
        let xmargin = (scrWidth - 2.0 * btnWidth!)/3.50
        let ymargin = (scrHight - 10.0 - 4.0 * btnWidth!) / 5.0
        
        let smallBtnWidth = echo.imageView?.frame.width
        let bigXmargin = (scrWidth - 2.0 * smallBtnWidth!)/3.50
        
        chipmunkPos.constant  = xmargin
        rightlow.constant = xmargin
        topright.constant = xmargin
        lowleft.constant = xmargin
        EchoX.constant =  bigXmargin
        ReverbX.constant =  bigXmargin
        
        chipmunkPosY.constant = ymargin
        RabbitPosY.constant = ymargin
        GapHeight.constant = ymargin
        DathY.constant = ymargin
        EchoY.constant =  ymargin
        ReverbY.constant =  ymargin
        stoppauseY.constant = 10 + volControl.frame.height
        RealStopY.constant =  10 + volControl.frame.height
        
        
        muteVolX.constant = 2
        maxVolX.constant = 2
        sliderLeftX.constant = 2
        sliderRightX.constant = 2
        
        muteVolY.constant = 10
        maxVolY.constant = 10
        sliderY.constant = 10
        
        gap2Btn.constant = 15
        
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
          audioPlayer = nil
          audioPlayer2 = nil
          audioData = nil
          audioFile = nil
          audioPlayerNode = nil
    }
    //
    //TODO: slider to change volume for high/low picth
    //      since this is not easily controlled
    @IBAction func volControllerChange(sender: UISlider) {
            ChangeAudioVloume()
    }
    
    @IBAction func playAudioSlow(sender: UIButton) {
        //hilight the btn
        activePlayer = PlayChoices.Block_snail
        stopAllAudio()
        playatRate(0.40)
    }
    @IBAction func playAudioFast(sender: UIButton) {
        activePlayer = PlayChoices.Block_rabbit;
        stopAllAudio()
        playatRate(1.70)
    }
    
    @IBAction func playDathVader(sender: UIButton) {
       activePlayer = PlayChoices.Block_dathvader
       stopAllAudio()
       playSoundwithChangedPitch(-1024.0)
        //tetsing audio frame with progress slider
       // playBuffer()
    }
    
    @IBAction func playChimunk(sender: UIButton) {
        activePlayer = PlayChoices.Block_chipmunk
        stopAllAudio()
        playSoundwithChangedPitch(1024.0)
    }
 
    
    //For reverb, we will simply repeat the process for the echoes.
    @IBAction func playReverb(sender: UIButton) {
        activePlayer = PlayChoices.Block_reverb;
        stopAllAudio()
        setSessionPlayer()
        stopOrpause.setImage(pauseImg, forState: .Normal)
        stopOrpause.hidden = false
        realStop.hidden = false
        
        playReverbAudio()
    }
    // echo...play the same audio just with a delay
    //We can play a delayed copy of our sound with a smaller amplitude.
    
    @IBAction func playEcho(sender: UIButton) {
        activePlayer = PlayChoices.Block_echo;
        stopAllAudio()
        
        setSessionPlayer()
        stopOrpause.setImage(pauseImg, forState: .Normal)
        stopOrpause.hidden = false
        realStop.hidden = false
        
        audioPlayer2.stop()
        let delay:NSTimeInterval = 0.30//300ms
        var playtime:NSTimeInterval  = audioPlayer2.deviceCurrentTime + delay
        
        //trigger didfinishingplaying callback
        audioPlayer2.delegate = self
        
        audioPlayer.stop()
        audioPlayer.rate = 1.0
        audioPlayer.currentTime = 0;
        audioPlayer.play()
        
        audioPlayer2.currentTime = 0
        //just a little lower in volume with a delay
        audioPlayer2.volume = 0.6 * audioPlayer.volume
        audioPlayer2.playAtTime(playtime)
    }
    

    @IBAction func StopAudio(sender: UIButton) {
        stopAllAudio()
    }
    
    //callback after finishing playing pitch change audio
    func hidestopbtn()
    {
        stopOrpause.hidden = true
        realStop.hidden = true
    }
    
    func ChangeAudioVloume()
    {
        switch (activePlayer) {
        case PlayChoices.Block_reverb:
            for i in 0...N {
                var player:AVAudioPlayer = reverbPlayers[i]
                var exponent:Double = -Double(i)/Double(N/2)
                var volume = Float(pow(Double(M_E), exponent))
                player.volume = volume * volControl.value
            }
        default:
            audioPlayer.volume = volControl.value;
            audioPlayer2.volume = volControl.value;
        }
    }
    
    func playSoundwithChangedPitch( pitchRate: Float)
    {
        
        realStop.hidden = false
        stopOrpause.setImage(pauseImg, forState: .Normal)
        stopOrpause.hidden = false
        
        
        setSessionPlayer()
        
        audioPlayerNode = AVAudioPlayerNode()
      
        audioEngine.attachNode(audioPlayerNode)
        var changePitchEffect = AVAudioUnitTimePitch()
        changePitchEffect.pitch = pitchRate
        audioEngine.attachNode(changePitchEffect)
        
        // no effect to audioEngine.outputNode
        // audioPlayerNode.volume = 0
        
       // var output = audioEngine.outputNode
       // audioEngine.connect(audioPlayerNode, to:changePitchEffect, format:nil)
       // audioEngine.connect(changePitchEffect, to:output, format:nil)
    
        // To control the volume once pitch changed, I use mixer..
        // but the problem is as you change the volume, it is too late to ajust the volume sionce the output is already done
        // we have to take this limitation for now.
 
        
        var mixer = audioEngine.mainMixerNode;
        audioEngine.connect(audioPlayerNode, to: changePitchEffect, format: mixer.outputFormatForBus(0))
        audioEngine.connect(changePitchEffect, to: mixer, format: mixer.outputFormatForBus(0))
        mixer.outputVolume = volControl.value
        
        //no delegate to know when finishing play....
        //callback function is completionHandler...seems there is a little delay??
        audioPlayerNode.scheduleFile(audioFile, atTime: nil, completionHandler:hidestopbtn)
        
        
        
        audioEngine.startAndReturnError(nil)

        if(audioEngine.running)
        {
            audioPlayerNode.play()
        }
        else
        {
            println("Eror in AudioEngin")
        }
        
    }
    
    func stopAllAudio()
    {
        if audioEngine.running && audioPlayerNode.playing {
            audioPlayerNode.stop()
            audioEngine.stop()
            audioEngine.reset()
        }
        
        
        if audioPlayer.playing {
            audioPlayer.stop()
        }
        if audioPlayer2.playing {
            audioPlayer2.stop()
        }
        for i in 0...N {
            var player:AVAudioPlayer = reverbPlayers[i]
            if player.playing {
                player.stop()
            }
        }
        
        
        stopOrpause.hidden = true
        realStop.hidden = true
        
        //close session
        AVAudioSession.sharedInstance().setActive(false, error: nil)

    }
    //Seems no easy way to rename...you have to delete and recreate.
    @IBAction func pauseAudio(sender: UIButton) {
            switch (activePlayer) {
                case PlayChoices.Block_snail, PlayChoices.Block_rabbit:
                    if audioPlayer.playing {
                        AVcurrentTime  = audioPlayer.currentTime
                        audioPlayer.pause()
                        isPaused = 1
                        stopOrpause.setImage(pauseImg, forState: .Normal)
                        stopOrpause.hidden = false
                    }
                    else
                    {
                        if(isPaused == 1)
                        {
                            // is it needed after pause??
                            //audioPlayer.currentTime = AVcurrentTime
                            //audioPlayer.prepareToPlay()
                            audioPlayer.play()
                        }
                    }
                    //reset icon: play or pause

                    if(isPaused == 1 && !audioPlayer.playing)
                    {
                        stopOrpause.setImage(playImg, forState: .Normal)
                    }
                    else
                    {
                        stopOrpause.setImage(pauseImg, forState: .Normal)
                    }
                    break;
                case PlayChoices.Block_chipmunk, PlayChoices.Block_dathvader:
                    if audioEngine.running && audioPlayerNode.playing {
                        isPaused = 1
                        audioPlayerNode.pause()
                        stopOrpause.setImage(pauseImg, forState: .Normal)
                        stopOrpause.hidden = false
                    }
                    else
                    {
                        if(isPaused == 1 ) {
                            audioPlayerNode.play()
                        }
                    }
                    //reset icon: play or pause
                    if(isPaused == 1 && !(audioEngine.running && audioPlayerNode.playing))
                    {
                        stopOrpause.setImage(playImg, forState: .Normal)
                    }
                    else
                    {
                        stopOrpause.setImage(pauseImg, forState: .Normal)
                    }
                    break;
                case  PlayChoices.Block_echo:
                    //when pause, what we do with 2nd player with 0.2 second delay
                    // you can click after 0.1 second after 1st payer starts
                    // easiest way
                    if audioPlayer.playing {
                       // AVcurrentTime  = audioPlayer.currentTime
                        audioPlayer.pause()
                        if audioPlayer2.playing
                        {
                            audioPlayer2.pause()
                        }
                        isPaused = 1
                        stopOrpause.setImage(pauseImg, forState: .Normal)
                        stopOrpause.hidden = false
                    }
                    else
                    {
                        if(isPaused == 1)
                        {
                            // is it needed after pause??
                            //audioPlayer.currentTime = AVcurrentTime
                            //audioPlayer.prepareToPlay()
                            audioPlayer.play()
                            if !audioPlayer2.playing
                            {
                                audioPlayer2.play()
                            }
                        }
                    }
                   //reset icon: play or pause
                    if(isPaused == 1 && !audioPlayer.playing)
                    {
                        stopOrpause.setImage(playImg, forState: .Normal)
                    }
                    else
                    {
                        stopOrpause.setImage(pauseImg, forState: .Normal)
                    }
                    break;
                case  PlayChoices.Block_reverb:
                    if(isPaused == 0){
                        for i in 0...N {
                            var player:AVAudioPlayer = reverbPlayers[i]
                            if(player.playing)
                            {
                                player.pause()
                                isPaused = 1
                            }
                        }
                        if(isPaused == 1 ) {
                            stopOrpause.setImage(playImg, forState: .Normal)
                        }
                        else
                        {
                            stopOrpause.setImage(pauseImg, forState: .Normal)
                        }
                    }
                    else{
                       //continue
                        playReverbAudio()
                        isPaused =  0
                        stopOrpause.setImage(pauseImg, forState: .Normal)
                    }
                    break;
                case  PlayChoices.Block_none:
                        println("No active player")
                default:
                        println("Should never be here!!!!") // use NSLog ?
        }
    }

    @IBAction func maxVolAudio(sender: UIButton) {
        volControl.value = 1.0
        ChangeAudioVloume()
    }
    
    @IBAction func muteAudio(sender: UIButton) {
        volControl.value = 0.0
        ChangeAudioVloume()
    }
    
    //fast/slow rate : snail vs rabbit
    func playatRate(rate : Float)
    {
        stopOrpause.setImage(pauseImg, forState: .Normal)
        stopOrpause.hidden = false
        realStop.hidden = false
        
        setSessionPlayer()
        
        //always start from start when click
        audioPlayer.currentTime = 0.0
        
        audioPlayer.rate=rate
        //audioPlayer.prepareToPlay()
        audioPlayer.play()

    }
    
    //should I keep th seesion alive until I quit the app?
    //NSLog instead of println
    func setSessionPlayer() {
     
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        if !session.setCategory(AVAudioSessionCategoryPlayback, error:&error) {
            println("could not set session category")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        if !session.setActive(true, error: &error) {
            println("could not make session active")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        //reset
        isPaused = 0
    }
    
    //this is based on above listed references from internet
    func playReverbAudio()
    {
        // 20ms produces detectable delays
        for i in 0...N {
            var curDelay:NSTimeInterval = delay*NSTimeInterval(i)
            var player:AVAudioPlayer = reverbPlayers[i]
            //M_E is e=2.718...
            //dividing N by 2 made it sound ok for the case N=10
            var exponent:Double = -Double(i)/Double(N/2)
            var volume = Float(pow(Double(M_E), exponent))
            player.volume = volume * volControl.value
            player.delegate = self
            player.playAtTime(player.deviceCurrentTime + curDelay)
        }
    }
    

    // when go back to prev. controller....nothing happend here if go back ???
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        println("leaving so soon???")
    }

}
