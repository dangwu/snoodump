#!/usr/bin/swift

import Cocoa
import Foundation

class RedditDownloader {
    
    private let dispatchGroup = DispatchGroup()
    
    func downloadImages(fromSubreddit subreddit: String? = nil) {
        downloadImages(fromURL: "https://www.reddit.com/r/\(subreddit ?? "pics").json")
        dispatchGroup.wait()
    }
    
    private func downloadImages(fromURL urlString: String, pageAfterToken: String? = nil) {
        dispatchGroup.enter()
        
        var redditUrl = urlString
        if let pageAfterToken = pageAfterToken {
            redditUrl = "\(redditUrl)?after=\(pageAfterToken)"
        }
        
        guard let requestURL = URL(string: redditUrl) else {
            dispatchGroup.leave()
            return
        }
        
        let request = URLRequest(url: requestURL)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            data, response, error in
            
            do {
                guard let data = data else {
                    self.dispatchGroup.leave()
                    return
                }
                guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
                    self.dispatchGroup.leave()
                    return
                }
                
                // Parse JSON for URLs to images to download
                let dataDict = json.object(forKey: "data") as! NSDictionary
                let childrenArr = dataDict.object(forKey: "children") as! [[String: AnyObject]]
                for postDict in childrenArr {
                    for (postKey, postValue) in postDict where postKey == "data" {
                        for (dataKey, dataValue) in postValue as! [String: AnyObject] where dataKey == "url" {
                            if let url = dataValue as? String {
                                // URL to an image found. Download it!
                                if url.lowercased().contains(".jpg") || url.lowercased().contains(".png") {
                                    self.downloadImageAtURL(url: URL(string: url)!)
                                }
                            }
                        }
                    }
                }
                
                if let pageAfterToken = dataDict.object(forKey: "after") as? String {
                    // Download next page of data
                    self.downloadImages(fromURL: urlString, pageAfterToken: pageAfterToken)
                }
                
            } catch let error as NSError {
                print("Error downloading json data from reddit: \(error.debugDescription)")
            }
            
            self.dispatchGroup.leave()
        })
        task.resume()
    }
    
    private func downloadImageAtURL(url: URL) {
        print("Downloading: \(url)\r")
        dispatchGroup.enter()
        
        let request = URLRequest(url: url)
        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            data, response, error in
            
            let fileName = "\(url.lastPathComponent)"
            
            if let desktopDirectoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                let folderURL = desktopDirectoryURL.appendingPathComponent("snoodump", isDirectory: true)
                try? FileManager.default.createDirectory(atPath: folderURL.path, withIntermediateDirectories: true, attributes: nil)
                let fileURL = folderURL.appendingPathComponent(fileName)
                
                // Save image to disk
                try? data?.write(to: fileURL, options: [])
                
                self.dispatchGroup.leave()
            }
        })
        task.resume()
    }
}

let redditDownloader = RedditDownloader()

if CommandLine.argc < 2 {
    // No arg
    redditDownloader.downloadImages()
} else {
    // Process arg
    let flag = CommandLine.arguments[1]
    switch flag {
    case "-s":
        redditDownloader.downloadImages(fromSubreddit: CommandLine.arguments[2])
    case "-r":
        redditDownloader.downloadImages(fromSubreddit: "random")
    default:
        let executableName = (CommandLine.arguments[0] as NSString).lastPathComponent
        print("Usage:")
        print("\(executableName)                  -->     download images from /r/pics")
        print("\(executableName) -s subreddit     -->     download images from the given subreddit")
        print("\(executableName) -r               -->     download images from a random subreddit")
        print("\n")
        exit(1)
    }
}
