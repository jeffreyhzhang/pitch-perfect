//
//  RecordAudioViewController.swift
//  PitchPerfect
//
//  Record up to 90 seconds audio to be played later on next controller
//  The recording will stop automatically after 90 seconds.
//  To avoid polluting disk space, use the same wav filename instead of unique name with timestamp
//
//
//  Created by Jeffrey Zhang on 3/6/15.
//  Copyright (c) 2015 JHZ. All rights reserved.
//
//

import UIKit
import AVFoundation

class RecordAudioViewController: UIViewController, AVAudioRecorderDelegate
{
    //IB items
    @IBOutlet weak var recordInProgress: UILabel!
    @IBOutlet weak var recordAudio: UIButton!
    @IBOutlet weak var stopRecord: UIButton!
    @IBOutlet weak var pause: UIButton!
    //constraint for positioning IB items
    @IBOutlet weak var stopY: NSLayoutConstraint!
    @IBOutlet weak var pauseY: NSLayoutConstraint!
    @IBOutlet weak var pauseX: NSLayoutConstraint!
    
    var audioRecorder: AVAudioRecorder!
    var recordedAudio: RecordedAudio!
    //paused at all, if paused no need re-init audio recording
    var paused = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // check to see do we have permissions to record Audio, init audioSession
        var error: NSError?
        var session = AVAudioSession.sharedInstance()
        if session.setCategory(AVAudioSessionCategoryPlayAndRecord,
            withOptions: .DuckOthers,
            error: &error){
                if session.setActive(true, error: nil){

                    session.requestRecordPermission{
                        [weak self](allowed: Bool) in
                        if !allowed{
                            println("No permission to record audio");
                        }
                    }
                } else {
                    println("We cannot activate audio session!")
                }
        } else {
          if let errmsg = error{
              println("An error occurred in setting audio session category. Error = \(errmsg)")
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        stopRecord.hidden = true
        pause.hidden = true
        recordInProgress.hidden = false
        recordInProgress.text="Tap to Record"
    }
    
    override func viewDidLayoutSubviews() {
        //positioning btns based on device display dimensions
        let halfscrWidth = UIScreen.mainScreen().bounds.width / 2.0
        let scrHight = UIScreen.mainScreen().bounds.height
        // get dimension size for two types of btns
        let btnWidth = stopRecord.imageView?.frame.width
        let tbnHeigth  = recordAudio.imageView?.frame.height
   
        let xmargin =  CGFloat( (halfscrWidth  -  1.5 * btnWidth!)/2.0 )
        let ymargin = (scrHight - 10.0 - btnWidth! - tbnHeigth!) / 4.0
        
        stopY.constant = ymargin
        pauseY.constant = ymargin
        pauseX.constant = xmargin

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //audio format is important, you cannot play wav file use kAudioFormatMPEG4AAC as AVFormatIDKey
    func audioRecordingSettings() -> [NSObject : AnyObject]{
        return [
            //AVFormatIDKey : kAudioFormatMPEG4AAC as NSNumber, //.m4a
            AVFormatIDKey : kAudioFormatLinearPCM as NSNumber,  // for wav format
            AVSampleRateKey : 16000.0 as NSNumber,
            AVNumberOfChannelsKey : 1 as NSNumber,
            AVEncoderAudioQualityKey : AVAudioQuality.Low.rawValue as NSNumber
        ]
    }
    
    @IBAction func recordAudio(sender: UIButton) {
        // display recording
        recordInProgress.text="Recording..."
        recordInProgress.textColor = UIColor(red:1.0, green:0.0, blue:0.0, alpha:1.0)
        recordInProgress.hidden=false
        stopRecord.hidden = false
        pause.hidden = false
        
        //Disable Record btn until it is done recording
        recordAudio.enabled = false
       
        if(!paused)
        {
            let dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let docsDir = dirPaths[0] as String
            //let fmt = NSDateFormatter()
            //fmt.dateFormat = "ddMMyyyy-HHmmss"
            //let recordingName = "Jeffrey" + fmt.stringFromDate(NSDate()) + ".wav"
            //why pollute my disk...overwritting the file is ok
            let recordingName = "JeffreyZhang.wav"
            let soundFileURL = NSURL.fileURLWithPathComponents([docsDir,recordingName])
            
            var audioSession = AVAudioSession.sharedInstance()
            audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord,error: nil)
            
            audioSession.setActive(true, error: nil)
            
            audioRecorder = AVAudioRecorder(URL: soundFileURL,settings: audioRecordingSettings(), error: nil)
            audioRecorder.delegate = self
            audioRecorder.meteringEnabled = true
            //calls prepareToRecordto create (or erases) an audio file
            audioRecorder.prepareToRecord()
        }
        audioRecorder.record()
        
        //automatically stop recording after 90 seconds to prevent pollution of disk space
        var delayInSeconds = 90.0
        var delayInNanoSeconds =  dispatch_time(DISPATCH_TIME_NOW, Int64(delayInSeconds * Double(NSEC_PER_SEC)))
        dispatch_after(delayInNanoSeconds, dispatch_get_main_queue(), stopRecodingNow)

    }
    
    @IBAction func pauseRecord(sender: UIButton) {
        if audioRecorder.recording
        {
          audioRecorder.pause()
          //enable record again
          recordAudio.enabled = true
          //change lable status
          recordInProgress.text="Tap Microphone to Continue Recording"
          paused = true
        }
    }
    
    //navigate to next controller when finishing recording and writting audio file
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder!, successfully flag: Bool) {
       recordInProgress.hidden=true
 
        if(flag) {
            recordedAudio = RecordedAudio(filePathUrl: recorder.url, title: recorder.url.lastPathComponent)
            self.performSegueWithIdentifier("stopRecording", sender: recordedAudio)
        }
        else
        {
            println("error in audioRecorderDidFinishRecording")
        }
        recordAudio.enabled = true
        stopRecord.hidden = true
        pause.hidden = true

    }
    
    override func prepareForSegue(segue: UIStoryboardSegue,  sender: AnyObject?){
        if(segue.identifier == "stopRecording"){
            // exception handling in swift?...may have cast exception
           let playAudioVC: PlayAudioViewController = segue.destinationViewController as PlayAudioViewController
            playAudioVC.audioData = sender as RecordedAudio
        }
    }
    
    @IBAction func stopRecordAudio(sender: UIButton) {
        stopRecodingNow()
    }
    
    func stopRecodingNow(){
        // it may have a delay in writting the file
        recordInProgress.text="Saving Audio File..."
        recordInProgress.textColor = UIColor(red:1.0, green:0.0, blue:0.0, alpha:1.0)
        
        audioRecorder.stop()
        
        var audioSession = AVAudioSession.sharedInstance()
        audioSession.setActive(false, error: nil)
        //Callback is delegated to segue instead of triggered by this btn click
        
    }
}
