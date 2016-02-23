//
//  NSFileManager.swift
//  rivierabuild
//
//  Created by Brandon Sneed on 2/24/15.
//  Copyright (c) 2015 TheHolyGrail. All rights reserved.
//

import Foundation

/*
- (NSString *)temporaryFile
{
NSString *fileName = [NSString stringWithFormat:@"%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], @"file.txt"];
NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
return [fileURL path];
}

+ (NSString *)temporaryFile
{
return [[NSFileManager defaultManager] temporaryFile];
}
*/

extension NSFileManager {
    
    func temporaryFile() -> NSString {
        let uniqueString = NSProcessInfo.processInfo().globallyUniqueString
        let filename = NSString(format: "%@_%@", uniqueString, "file.txt")
        let tempPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(filename as String)
        let fileURL = NSURL.fileURLWithPath(tempPath)
        return fileURL.path!
    }
    
    class func temporaryFile() -> NSString {
        return NSFileManager.defaultManager().temporaryFile()
    }
}
