//
//  RivieraBuildAPI.swift
//  rivierabuild
//
//  Created by Brandon Sneed on 2/27/15.
//  Copyright (c) 2015 TheHolyGrail. All rights reserved.
//

import Foundation

public struct RivieraBuildAPI {
    
    private let baseURL: String = "https://apps.rivierabuild.com"
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func lastUploadedBuildInfo(appID: String) -> JSON? {
        var json: JSON? = nil;
        
        let session = NSURLSession.sharedSession()
        
        let urlString = baseURL + "/v1/applications/" + appID + "/builds/latest?api_key=" + apiKey
        let url = NSURL(string: urlString)!
        
        // we want this call to be synchronous
        let semaphore = dispatch_semaphore_create(0)
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
            if let data = data {
                let dataString: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
                json = JSON(string: dataString)
            }
            
            dispatch_semaphore_signal(semaphore)
        }
        
        task.resume()
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        
        return json
    }
    
    public func uploadBuild(filePath: String, parameters: Dictionary<String, AnyObject>) -> JSON? {
        var json: JSON? = nil;
        
        let session = NSURLSession.sharedSession()
        
        let urlString = baseURL + "/api/upload?api_key=" + apiKey
        let url = NSURL(string: urlString)!
        
        // we want this call to be synchronous
        let semaphore = dispatch_semaphore_create(0)
        
        let request = NSMutableURLRequest(URL: url)
        let boundaryConstant = "myRandomBoundary12345";
        let contentType = "multipart/form-data;boundary=" + boundaryConstant
        
        request.HTTPMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        // see if the file exists.
        let fileManager = NSFileManager.defaultManager()
        let exists = fileManager.fileExistsAtPath(filePath)
        
        if exists {

            let fileData = NSData(contentsOfFile: filePath)
            
            // create upload data to send
            let uploadData = NSMutableData()
            
            // add image
            uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Disposition: form-data; name=\"file\"; filename=\"build.ipa\"\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData("Content-Type: image/png\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
            uploadData.appendData(fileData!)
            
            // add parameters
            for (key, value) in parameters {
                uploadData.appendData("\r\n--\(boundaryConstant)\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)
                uploadData.appendData("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)".dataUsingEncoding(NSUTF8StringEncoding)!)
            }
            uploadData.appendData("\r\n--\(boundaryConstant)--\r\n".dataUsingEncoding(NSUTF8StringEncoding)!)

            let task = session.uploadTaskWithRequest(request, fromData: uploadData) { (data, response, error) -> Void in
                if let data = data {
                    let dataString: String = NSString(data: data, encoding: NSUTF8StringEncoding)! as String
                    json = JSON(string: dataString)
                }
                
                dispatch_semaphore_signal(semaphore)
            }
            
            task.resume()
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        }
        
        return json
        
    }
}