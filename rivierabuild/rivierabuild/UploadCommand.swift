//
//  UploadCommand.swift
//  rivierabuild
//
//  Created by Brandon Sneed on 2/24/15.
//  Copyright (c) 2015 TheHolyGrail. All rights reserved.
//

//  Definitely *not* my best code, but with Testflight shutting down, I had 2 days
//  to get something working with Jenkins. :(  Bad Brandon, Bad!  I look forward
//  to your improvements, community!

import Foundation

class UploadCommand: Command {
    
    // flags
    private var randompasscode: Bool = false
    private var verbose: Bool = false
    private var useGitLogs: Bool = true

    // key/value pairs
    private var availability: String? = nil
    private var passcode: String? = nil
    private var apiKey: String? = nil
    private var appID: String? = nil
    private var note: String? = ""
    private var version: String? = nil
    private var buildNumber: String? = nil
    private var projectDir: String? = nil
    
    // key/value pairs for slack
    /*
    I need to figure out how to do piping in swift and break this bit into it's own command.
    */
    private var slackHookURL: String? = nil
    private var slackChannel: String? = "#non-existant-channel"
    
    // internal vars
    private var rivieraURL: String? = nil
    private var commitHash: String? = nil
    private var lastCommitHash: String? = nil
    
    override func commandName() -> String {
        return "upload"
    }
    
    override func commandShortDescription() -> String {
        return "Uploads IPAs to RivieraBuild"
    }
    
    override func commandSignature() -> String {
        return "<displayname> <ipa>"
    }
    
    override func handleOptions() {
        onFlags(["--verbose"], block: { (flag) -> () in
            self.verbose = true
        }, usage: "Show more details about what's happening.")

        onFlags(["--disablegitlog"], block: { (flag) -> () in
            self.useGitLogs = false
        }, usage: "Disables appending the git log to the notes.")
        
        onFlags(["--randompasscode"], block: { (flag) -> () in
            self.randompasscode = true
            let randomPassword = PasswordGenerator().generateHex()
            self.passcode = randomPassword
        }, usage: "Generate a random passcode.")
        
        onKeys(["--availability"], block: {key, value in
            self.availability = value
        }, usage: "Specifies the availablility of the build.\nUse the following values:\n\n 10_minutes\n 1_hour\n 3_hours\n 6_hours\n 12_hours\n 24_hours\n 1_week\n 2_weeks\n 1_month\n 2_months", valueSignature: "availability")
        
        onKeys(["--passcode"], block: { (key, value) -> () in
            self.passcode = value
        }, usage: "Specify the passcode to use for the build.", valueSignature: "passcode")
        
        onKeys(["--apikey"], block: { (key, value) -> () in
            self.apiKey = value
        }, usage: "Your RivieraBuild API key.", valueSignature: "apikey")
        
        onKeys(["--appid"], block: { (key, value) -> () in
            self.appID = value
        }, usage: "Your App ID in RivieraBuild.", valueSignature: "appid")
        
        onKeys(["--note"], block: { (key, value) -> () in
            self.note = value
        }, usage: "The note to show in RivieraBuild", valueSignature: "note")
        
        onKeys(["--projectdir"], block: { (key, value) -> () in
            self.projectDir = value
        }, usage: "The directory of your project, for Git logs.", valueSignature: "projectdir")
        
        // slack config bits
        onKeys(["--slackhookurl"], block: { (key, value) -> () in
            self.slackHookURL = value
        }, usage: "Your Slack webhook URL.", valueSignature: "slackhookurl")

        onKeys(["--slackchannel"], block: { (key, value) -> () in
            self.slackChannel = value
        }, usage: "The Slack channel to post to.", valueSignature: "slackchannel")
    }
    
    override func execute() -> CommandResult {
        var result: CommandResult = .Success
        
        let riviera = RivieraBuildAPI(apiKey: apiKey!)
        
        // if we were given a projectDir, is it valid?
        if let projectDir = projectDir {
            let fileManager = NSFileManager.defaultManager()
            var isDir: ObjCBool = false
            let exists = fileManager.fileExistsAtPath(projectDir, isDirectory: &isDir)
            
            if !isDir {
                return .Failure("The specified value for project dir is not a directory or invalid.")
            }

        }
        
        // get the current commit hash.
        // we'll send this to riviera so we can query it next time.
        commitHash = currentCommitHash()
        
        if let commitHash = commitHash {
            if count(commitHash) == 0 {
                // we don't have it, lets bolt.
                return .Failure("Unable to query the current commit hash.  Is this a Git repository?")
            }
        }
        
        // get the last commit hash, we need it later if it's there.
        var json = riviera.lastUploadedBuildInfo(appID!)
        
        if let json = json {
            lastCommitHash = json["commit_sha"].asString
        }
        
        if useGitLogs {
            // try and get the build notes from git log.
            // these will be merged with whatever was passed along in --note.
            if commitHash != nil && lastCommitHash != nil {
                if let gitNotes = gitLogs(lastCommitHash!) {
                    if let note = self.note {
                        self.note = note.stringByAppendingFormat("\n\n%@", gitNotes)
                    } else {
                        self.note = gitNotes
                    }
                }
            }
        }
        
        // try to send it to riviera
        
        result = sendToRiviera()
        switch result {
        case .Success:
            0
        case .Failure(let string):
            return result
        }
        
        // get the version and build from the one we just uploaded so we can use it for slack.
        fillLastVersionAndBuildNumber()
        
        // try to post it to slack
        result = postToSlack()
        switch result {
        case .Success:
            0
        case .Failure(let string):
            return result
        }
        
        return result
    }
    
    func postToSlack() -> CommandResult {
        if slackHookURL != nil {
            // Build the stuff we're going to display on slack...
            
            // displayname is a required arg, so force unwrap it.
            let displayName = arguments["displayname"] as! String
            
            // we'll have a URL here too (or it would have failed before) so unwrap rivieraURL.
            var slackNote: String = String(format: "_*%@*_\nInstall URL: %@", displayName, rivieraURL!)
            
            if let passcode = passcode {
                slackNote = slackNote.stringByAppendingFormat("\nPasscode: %@", passcode)
            }
            
            if let version = version {
                slackNote = slackNote.stringByAppendingFormat("\nVersion: %@", version)
            }
            
            if let buildNumber = buildNumber {
                slackNote = slackNote.stringByAppendingFormat("\nBuild Number: %@", buildNumber)
            }
            
            if let note = note {
                slackNote = slackNote.stringByAppendingFormat("\nNotes:\n\n %@", note)
            }

            let slack = SlackWebHookAPI(webHookURL: slackHookURL!)
            if slack.postToSlack(slackChannel!, text: slackNote) == false {
                return .Failure("Slack posting failed.")
            }
            
            return .Success
        } else {
            // we just won't be sending to slack, so don't fail.
            return .Success
        }
    }
    
    func sendToRiviera() -> CommandResult {
        // ipa is a required arg, so force unwrap it.
        let ipa = arguments["ipa"] as! String
        // see if the file exists.
        let fileManager = NSFileManager.defaultManager()
        let exists = fileManager.fileExistsAtPath(ipa)
        
        if exists {

            var parameters = Dictionary<String, AnyObject>()
            
            if availability != nil {
                parameters["availability"] = availability!
            } else {
                return .Failure("--availability <value> is a required option.")
            }
            
            if passcode != nil {
                parameters["passcode"] = passcode!
            }
            
            if appID != nil {
                parameters["app_id"] = appID!
            }
            
            if note != nil {
                parameters["note"] = note!
            }
            
            if version != nil {
                parameters[""] = version!
            }
            
            if buildNumber != nil {
                parameters["build_number"] = buildNumber!
            }
            
            if commitHash != nil {
                parameters["commit_sha"] = commitHash!
            }

            println("SHA sent to riviera: \(commitHash!)")
            
            let riviera = RivieraBuildAPI(apiKey: apiKey!)
            let json = riviera.uploadBuild(ipa, parameters: parameters)

            if let json = json {
                if let resultURL = json["file_url"].asString {
                    self.rivieraURL = resultURL
                }
            }

            if rivieraURL == nil {
                return .Failure("Failed to get the result URL from RivieraBuild.")
            }
            
            return .Success
        } else {
            return .Failure("The IPA specified does not exist.")
        }
    }
    
    func currentCommitHash() -> String? {
        var commitHash: String = ""

        let currentPath = NSFileManager.defaultManager().currentDirectoryPath
        if let projectDir = projectDir {
            NSFileManager.defaultManager().changeCurrentDirectoryPath(projectDir)
        }
        
        let command = "git log --format='%H' -n 1"
        if verbose {
            println(command)
        }
        let status: Int32 = shellCommand(command) { (status, output) -> Void in
            if status == 0 {
                commitHash = output.stringByReplacingOccurrencesOfString("\n", withString: "")
            }
        }
        
        if let projectDir = projectDir {
            NSFileManager.defaultManager().changeCurrentDirectoryPath(currentPath)
        }
        
        return commitHash
    }
    
    func lastBuildCommitHash() -> String? {
        if (appID == nil) || (apiKey == nil) {
            return nil
        }
        
        var commitHash: String? = nil
        
        let riviera = RivieraBuildAPI(apiKey: apiKey!)
        let json = riviera.lastUploadedBuildInfo(appID!)

        if let json = json {
            if let hash = json["commit_sha"].asString {
                if hash != "null" {
                    commitHash = hash
                }
            }
        }
        
        return commitHash
    }
    
    func fillLastVersionAndBuildNumber() {
        if (appID == nil) || (apiKey == nil) {
            version = nil
            buildNumber = nil
            return
        }

        let riviera = RivieraBuildAPI(apiKey: apiKey!)
        let json = riviera.lastUploadedBuildInfo(appID!)
        
        if let json = json {
            if let version = json["version"].asString {
                if version != "null" && count(version) > 0 {
                    self.version = version
                }
            }
            if let buildNumber = json["build_number"].asString {
                if buildNumber != "null" && count(buildNumber) > 0 {
                    self.buildNumber = buildNumber
                }
            }
        }
    }
    
    func gitLogs(sinceHash: String) -> String? {
        
        var commitNotes: String? = nil
        
        let currentPath = NSFileManager.defaultManager().currentDirectoryPath
        if let projectDir = projectDir {
            NSFileManager.defaultManager().changeCurrentDirectoryPath(projectDir)
        }
        
        let command = String(format: "git log --oneline --no-merges %@..HEAD --format=\"- %%s   -- %%cn\"", sinceHash)
        if verbose {
            println(command)
        }
        let status: Int32 = shellCommand(command) { (status, output) -> Void in
            if status == 0 {
                commitNotes = output
                
                // commitNotes ends up containing the log for the commit referenced and an extra \n.  I don't know
                // how to exclude it, so i'm doing this hacky thing.  :(
                
                var logs: [String] = commitNotes!.componentsSeparatedByString("\n")
                
                // escape the carriage returns
                commitNotes = "\n".join(logs)
            }
        }
        
        if let projectDir = projectDir {
            NSFileManager.defaultManager().changeCurrentDirectoryPath(currentPath)
        }
        
        return commitNotes
    }
    
}


