//
//  EpisodeThreadViewController.swift
//  Aozora
//
//  Created by Paul Chavarria Podoliako on 8/8/15.
//  Copyright (c) 2015 AnyTap. All rights reserved.
//

import Foundation

public class EpisodeThreadViewController: ThreadViewController {
    
    @IBOutlet weak var episodeImage: UIImageView!
    @IBOutlet weak var animeTitle: UILabel!
    @IBOutlet weak var episodeTitle: UILabel!
    @IBOutlet weak var airedLabel: UILabel!
    
    var episode: Episode?
    var anime: Anime?
    
    public override func initWithThread(thread: Thread, postType: CommentViewController.PostType) {
        self.thread = thread
        self.postType = postType
    }
    
    public func initWithEpisode(episode: Episode, anime: Anime, postType: CommentViewController.PostType) {
        self.episode = episode
        self.anime = anime
        self.postType = postType
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        title = "Loading..."
        navigationItem.leftBarButtonItems = nil
    }
    
    override func updateUIWithThread(thread: Thread) {
        super.updateUIWithThread(thread)
        
        if let anime = thread.anime {
            animeTitle.text = anime.title
        }
        
        if let episode = thread.episode {
            episodeImage.setImageFrom(urlString: episode.imageURLString(), animated: true)
            if let title = episode.title {
                episodeTitle.text = "Episode \(episode.number) · \(title) discussion"
            } else {
                episodeTitle.text = "Episode \(episode.number) discussion"
            }
            
            if let firstAired = episode.firstAired {
                airedLabel.text = "Aired on \(firstAired.mediumDate())"
            } else {
                airedLabel.text = ""
            }
        }
        
        if let anime = thread.anime, let animeTitle = anime.title, let episode = thread.episode {
            title = "\(animeTitle) - Episode \(episode.number)"
        } else {
            title = "Episode Discussion"
        }
    }
    
    override func fetchThread() {
        super.fetchThread()
        
        if let episode = episode {
            let query = Thread.query()!
            query.limit = 1
            query.whereKey("episode", equalTo: episode)
            query.includeKey("anime")
            query.includeKey("episode")
            query.includeKey("startedBy")
            query.findObjectsInBackgroundWithBlock({ (result, error) -> Void in
                
                if let error = error {
                    // TODO: Show error
                } else if let result = result, let thread = result.last as? Thread {
                    self.thread = thread
                } else if let episode = self.episode, let anime = self.anime {
                    
                    // Create lazily
                    let thread = Thread()
                    thread.episode = episode
                    thread.anime = anime
                    thread.locked = false
                    thread.replies = 0
                    thread.saveInBackgroundWithBlock({ (result, error) -> Void in
                        if result {
                            self.thread = thread
                        }
                    })
                }
            })
        }
    }
    
    override func updateThread() {
        super.updateThread()
        
        let query = Post.query()!
        query.skip = 0
        query.whereKey("replyLevel", equalTo: 0)
        query.whereKey("thread", equalTo: thread!)
        query.orderByAscending("createdAt")
        query.includeKey("postedBy")
        query.includeKey("replies")
        fetchController.configureWith(self, query: query, tableView: tableView)
    }
    
    // MARK: - IBAction
    
    public override func replyToThreadPressed(sender: AnyObject) {
        super.replyToThreadPressed(sender)
        
        if let thread = thread {
            let comment = ANParseKit.commentViewController()
            comment.initWithThread(thread, postType: postType, delegate: self)
            presentViewController(comment, animated: true, completion: nil)
        }
    }
}