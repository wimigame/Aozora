//
//  MALScrapper.swift
//  AnimeNow
//
//  Created by Paul Chavarria Podoliako on 5/23/15.
//  Copyright (c) 2015 AnyTap. All rights reserved.
//

import UIKit
import Bolts

public class MALScrapper {
    
    var viewController: UIViewController
    
    public init(viewController: UIViewController) {
        self.viewController = viewController
    }
    
    public enum TopicType: String {
        case Sticky = "Sticky"
        case Poll = "Poll"
        case Normal = "Normal"
    }
    
    // Classes
    
    public class Review {
        public var avatarUrl: String
        public var date: String
        public var helpful: String
        public var rating: Int
        public var review: String
        public var username: String
        
        init(avatarUrl: String, date: String, helpful:String, rating: Int, review: String, username: String) {
            
            self.avatarUrl = avatarUrl.stringByRemovingOccurencesOfString(["background-image:url(",")","thumbs/","_thumb"])
            self.date = date.stringByRemovingOccurencesOfString(["| "])
            self.helpful = helpful
            self.rating = rating
            self.review = review
            self.username = username
            
        }
    }
    
    public class Topic {
        
        public var id: Int
        public var title: String
        public var fromUser: String
        public var date: String
        public var replies: Int
        public var type: TopicType
        public var lastPost: Post
        
        public var posts: [Post] = []
        
        init(id: Int, title: String, fromUser: String, date: String, replies: Int, type: TopicType, lastPost: Post) {
            self.id = id
            self.title = title
            self.fromUser = fromUser
            self.date = date
            self.replies = replies
            self.type = type
            self.lastPost = lastPost
        }
    }
    
    public class Post {
        public var id: String = ""
        public var user: String = ""
        public var date: String = ""
        public var fullDate: String = ""
        public var userAvatar: String = ""
        
        public var content: [Content] = []
        
        public enum ContentType {
            case Text
            case Image
            case Video
        }
        
        public class Content {
            public var type: ContentType
            public var content: String
            public var formats: [(attribute: String,value: AnyObject,range: NSRange)]
            public var links: [(url: NSURL, text: String)]
            public var level: Int // 0 normal post // 1: reply // 2: reply of reply
            
            init(type: ContentType, content: String, formats: [(attribute: String,value: AnyObject,range: NSRange)], links: [(url: NSURL, text: String)], level: Int) {
                self.type = type
                self.content = content
                self.formats = formats
                self.level = level
                self.links = links
            }
        }
        
    }
    
    // Functions
    
    func malTitleToSlug(title: String) -> String {
        return title
            .stringByReplacingOccurencesOfString([" ","/"], withString: "_")
            .stringByRemovingOccurencesOfString(["%"])
    }
    
    public func reviewsFor(#anime: Anime) -> BFTask{
        let completion = BFTaskCompletionSource()
        
        let malSlug = malTitleToSlug(anime.title!)
        let requestURL = "http://myanimelist.net/anime/\(anime.myAnimeListID)/\(malSlug)/reviews"
        
        let encodedRequest = requestURL.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
        
        
        viewController.webScraper.scrape(encodedRequest) { (hpple) -> Void in
            if hpple == nil {
                println("hpple is nil")
                completion.setError(NSError())
                return
            }
            
            let results = hpple.searchWithXPathQuery("//div[@class='box-unit4']") as! [TFHppleElement]
            
            var reviews: [Review] = []
            
            for result in results {
                let avatarString = result.hppleElementFor(path: [0,0,0])?.objectForKey("style")
                let username = result.hppleElementFor(path: [0,1,0,0])?.text()
                let score = result.hppleElementFor(path: [0,1,1,1])?.text()
                let review = result.hppleElementFor(path: [1,0,0,0])?.childrenContentByRemovingHtml()
                let date = result.hppleElementFor(path: [2,0])?.content
                let currentHelpful = result.hppleElementFor(path: [2,1])?.text()
                let totalHelpful = result.hppleElementFor(path: [2,2])?.content
                
                if let _ = avatarString {
                    var reviewStruct = Review(
                        avatarUrl: avatarString ?? "",
                        date: date ?? "",
                        helpful: (currentHelpful ?? "") + (totalHelpful ?? ""),
                        rating: score!.toInt() ?? 0,
                        review: review ?? "",
                        username: username ?? "")
                    reviews.append(reviewStruct)
                }
            }
            
            completion.setResult(reviews)
        }
        
        return completion.task
    }
    
    public func topicsFor(#anime: Anime) -> BFTask {
        let completion = BFTaskCompletionSource()
        let requestURL = "http://myanimelist.net/forum/?animeid=\(anime.myAnimeListID)"
        
        viewController.webScraper.scrape(requestURL) { (hpple) -> Void in
            if hpple == nil {
                println("hpple is nil")
                completion.setError(NSError())
                return
            }
            
            var results = hpple.searchWithXPathQuery("//table[@id='forumTopics']/tbody/tr") as! [TFHppleElement]
            
            // Removing header
            results.removeAtIndex(0)
            
            var topics: [Topic] = []
            
            for result in results {
                
                var type: TopicType = .Normal
                var topicID = result.hppleElementFor(path: [1,0])?.objectForKey("href")
                let firstElement = result.hppleElementFor(path: [1,0])
                var title = firstElement!.text() != nil ? firstElement?.text() : firstElement?.content
                
                if title == "Sticky:" {
                    type = .Sticky
                    title = result.hppleElementFor(path: [1,1])?.text()
                    topicID = result.hppleElementFor(path: [1,1])?.objectForKey("href")
                } else if title == "Poll:" {
                    type = .Poll
                    title = result.hppleElementFor(path: [1,1])?.text()
                    topicID = result.hppleElementFor(path: [1,1])?.objectForKey("href")
                }
                
                let fromUser = result.hppleElementFor(path: [1,4,0])?.text()
                let date = result.hppleElementFor(path: [1,5])?.text()
                var replies = result.hppleElementFor(path: [2])?.text()
                let lastReplyFromUser = result.hppleElementFor(path: [3,1])?.text()
                let lastReplyDate = result.hppleElementFor(path: [3,4])?.content
                
                topicID = topicID?.stringByRemovingOccurencesOfString(["/forum/?topicid="])
                replies = replies?.stringByRemovingOccurencesOfString([","])
                
                if let _ = topicID {
                    var lastPost = Post()
                    lastPost.user = lastReplyFromUser ?? ""
                    lastPost.date = lastReplyDate ?? ""
                    
                    var topic = Topic(
                        id: topicID?.toInt() ?? 0,
                        title: title ?? "",
                        fromUser: fromUser ?? "",
                        date: date ?? "",
                        replies: replies?.toInt() ?? 0,
                        type: type,
                        lastPost: lastPost)
                    topics.append(topic)
                }
            }
            
            completion.setResult(topics)
        }
        
        return completion.task
    }
    
    public func postsFor(#topic: Topic) -> BFTask {
        let completion = BFTaskCompletionSource()
        
        let requestURL = "http://myanimelist.net/forum/?topicid=\(topic.id)"
        
        viewController.webScraper.scrape(requestURL) { (hpple) -> Void in
            if hpple == nil {
                println("hpple is nil")
                completion.setError(NSError())
                return
            }
            
            var results = hpple.searchWithXPathQuery("//div[@class='box-unit4 pt12 pb12 pl12 pr12']") as! [TFHppleElement]
            
            var posts: [Post] = []
            
            for result in results {
                
                var postID = result.objectForKey("id")
                var avatar = result.hppleElementFor(path: [1,0,0])?.objectForKey("style")
                var username: String?
                var date: String?
                if avatar != nil {
                    avatar = avatar!.stringByRemovingOccurencesOfString(["background-image:url(",")"])
                    username = result.hppleElementFor(path: [1,1,0,0])?.text()
                    date = result.hppleElementFor(path: [1,1,1])?.text()
                } else {
                    username = result.hppleElementFor(path: [1,0,0,0])?.text()
                    date = result.hppleElementFor(path: [1,0,1])?.text()
                }
                
                var allContent: [Post.Content] = []
                
                if let contents = result.hppleElementFor(path: [2,0,0]),
                let children = contents.children {
                    for content in children {
                        let lastContent = allContent.last?.level == 0 ? allContent.last : nil
                        if let newContent = self.scrapePostContent(content as! TFHppleElement, lastContent: lastContent, inheritedFormats:[], currentLevel: 0, currentLocation: 0) {
                            allContent += newContent
                        }
                    }
                }
                
                if let _ = postID {
                    var post = Post()
                    post.user = username ?? ""
                    post.date = date ?? ""
                    post.id = postID
                    post.userAvatar = avatar ?? ""
                    post.content = allContent
                    posts.append(post)
                }
            }
            
            completion.setResult(posts)
        }
        
        return completion.task
    }
    
    func scrapePostContent(
        content: TFHppleElement,
        lastContent: Post.Content?,
        inheritedFormats: [(attribute: String,value: AnyObject,range: NSRange)],
        currentLevel: Int,
        currentLocation: Int) -> [Post.Content]? {
        
        switch content.tagName {
        // Image
        case "img" where content.objectForKey("src") != nil:
            let contentObject = Post.Content(type: Post.ContentType.Image, content: content.objectForKey("src"), formats:[], links:[], level: currentLevel)
            return [contentObject]
            
        // Reply
        case "div" where content.objectForKey("class") == "quotetext":
            var replyContent: [Post.Content] = []
            for content in content.children as! [TFHppleElement] {
                let lastContent = replyContent.last?.level == currentLevel+1 ? replyContent.last : nil
                if let newContent = scrapePostContent(content, lastContent: lastContent, inheritedFormats: inheritedFormats, currentLevel: currentLevel+1, currentLocation: 0) {
                    replyContent += newContent
                }
            }
            return replyContent
            
        // Text
        case "a": fallthrough
        case "span": fallthrough
        case "i": fallthrough
        case "u": fallthrough
        case "b": fallthrough
        case "strong": fallthrough
        case "br": fallthrough
        case "text":
            
            if let lastObject = lastContent where lastObject.type == Post.ContentType.Text {
                let (content, formats, links) = contentsForElement(content, inheritedFormats: inheritedFormats, links: [], currentLocation: count(lastObject.content))
                lastObject.content += content
                lastObject.formats += formats
                lastObject.links += links
                
            } else {
                let (content, formats, links) = contentsForElement(content, inheritedFormats: inheritedFormats, links: [], currentLocation: 0)
                let contentObject = Post.Content(type: Post.ContentType.Text, content: content, formats:formats, links: links, level: currentLevel)
                return [contentObject]
            }
            
        default: break;
        }
        
        return nil
    }
    
    func contentsForElement(
        element: TFHppleElement,
        inheritedFormats: [(attribute: String,value: AnyObject,range: NSRange)],
        links: [(url: NSURL, text: String)],
        currentLocation: Int)
        -> (content:String, formats:[(attribute: String,value: AnyObject,range: NSRange)], links: [(url: NSURL, text: String)]) {
        var allContent = ""
        var allInheritedFormats = inheritedFormats
        var allLinks = links
                
        var newFormats: [(attribute: String, value: AnyObject)] = []
            
        allContent += elementText(element)

            
        for child in element.children as! [TFHppleElement] {
            
            switch child.tagName {
            case "text":
                allContent += child.content
            case "br":
                allContent += "\n"
            case "a": fallthrough
            case "span": fallthrough
            case "b": fallthrough
            case "i": fallthrough
            case "u": fallthrough
            case "strong":
                let lastChild = child.children.last as! TFHppleElement
                if child.children.count == 1 &&
                (lastChild.isTextNode() || lastChild.text() != nil) {
                    let content = lastChild.text() ?? lastChild.content ?? ""
                    //let range = NSRange(location: currentLocation, length: count(content))
                    allContent += content
                    
                    if child.tagName == "a" {
                        allLinks.append(url: NSURL(string: child.objectForKey("href"))!, text: content)
                    }
                    
                } else {
                    let (content, formats, links) = contentsForElement(child, inheritedFormats: inheritedFormats, links: links, currentLocation: count(allContent)+currentLocation)
                    allContent += content
                    allInheritedFormats += formats
                    allLinks += links
                }
            default:
                break
            }
        }
        return (allContent,allInheritedFormats, allLinks)
    }
    
    func elementText(element: TFHppleElement) -> String {
        switch element.tagName {
        case "text":
            return element.content
        case "br":
            return "\n"
        default:
            return ""
        }
    }
    
}

extension String {
    func stringByRemovingOccurencesOfString(occurences: [String]) -> String {
        var allOccurences = occurences
        var finalString = self
        
        while allOccurences.count > 0 {
            var occurence = allOccurences[0]
            finalString = finalString.stringByReplacingOccurrencesOfString(occurence, withString: "")
            allOccurences.removeAtIndex(0)
        }
        
        return finalString
    }
    
    func stringByReplacingOccurencesOfString(occurences: [String], withString: String) -> String {
        var allOccurences = occurences
        var finalString = self
        
        while allOccurences.count > 0 {
            var occurence = allOccurences[0]
            finalString = finalString.stringByReplacingOccurrencesOfString(occurence, withString: withString)
            allOccurences.removeAtIndex(0)
        }
        
        return finalString
    }
}