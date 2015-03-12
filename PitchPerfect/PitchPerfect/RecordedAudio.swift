//
//  RecordedAudio.swift
//  PitchPerfect
//
//  This acts as model in MVC 
//  Recorded audio will pass from first controller to next controller
//
//
//  Created by JeffreyLee on 3/6/15.
//  Copyright (c) 2015 JHZ. All rights reserved.
//

import Foundation

class RecordedAudio: NSObject{
    var filePathUrl: NSURL!
    var title: String!
    //constructor
    init(filePathUrl: NSURL!, title: String!)
    {
        self.filePathUrl = filePathUrl
        self.title = title
    }
}