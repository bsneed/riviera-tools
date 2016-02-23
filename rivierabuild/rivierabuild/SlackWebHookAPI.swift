//
//  SlackWebHook.swift
//  rivierabuild
//
//  Created by Brandon Sneed on 2/27/15.
//  Copyright (c) 2015 TheHolyGrail. All rights reserved.
//

import Foundation

public struct SlackWebHookAPI {
    
    private let webHookURL: String
    
    init(webHookURL: String) {
        self.webHookURL = webHookURL
    }
    
    // returns 'true' if successful, otherwise, 'false'.
    public func postToSlack(channel: String, text: String) -> Bool {
        var result: Bool = false
        let session = NSURLSession.sharedSession()
        
        let url = NSURL(string: webHookURL)
        if let url = url {
            
            // we want this call to be synchronous
            let semaphore = dispatch_semaphore_create(0)
            
            let request = NSMutableURLRequest(URL: url)
            request.HTTPMethod = "POST"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            
            var contents = Dictionary<String, String>()
            
            contents["channel"] = channel
            contents["text"] = text
            
            let jsonPayload = JSON(contents)
            let tempString = jsonPayload.toString(true)
            let data = tempString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            
            request.HTTPBody = data
            
            let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
                if let data = data {
                    let dataString: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
                    if dataString == "ok" {
                        result = true
                    } else {
                        print("postToSlack returned: %@", dataString)
                    }
                }
                
                dispatch_semaphore_signal(semaphore)
            }
            
            task.resume()
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        }
        
        return result;
    }
}