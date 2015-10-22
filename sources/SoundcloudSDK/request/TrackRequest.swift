//
//  TrackRequest.swift
//  SoundcloudSDK
//
//  Created by Kevin DELANNOY on 25/04/15.
//  Copyright (c) 2015 Kevin Delannoy. All rights reserved.
//

import UIKit

public extension Track {
    internal static let BaseURL = NSURL(string: "https://api.soundcloud.com/tracks")!

    /**
    Load track with a specific identifier

    - parameter identifier: The identifier of the track to load
    - parameter completion: The closure that will be called when track is loaded or upon error
    */
    public static func track(identifier: Int, completion: SimpleAPIResponse<Track> -> Void) {
        let URL = BaseURL.URLByAppendingPathComponent("\(identifier).json")
        let parameters = ["client_id": Soundcloud.clientIdentifier!]

        let request = Request(URL: URL, method: .GET, parameters: parameters, parse: {
            if let track = Track(JSON: $0) {
                return .Success(track)
            }
            return .Failure(GenericError)
            }, completion: { result, response in
                completion(SimpleAPIResponse(result))
        })
        request.start()
    }

    /**
    Load tracks with specific identifiers

    - parameter identifiers: The identifiers of the tracks to load
    - parameter completion:  The closure that will be called when tracks are loaded or upon error
    */
    public static func tracks(identifiers: [Int], completion: SimpleAPIResponse<[Track]> -> Void) {
        let URL = BaseURL
        let parameters = [
            "client_id": Soundcloud.clientIdentifier!,
            "ids": identifiers.map { "\($0)" }.joinWithSeparator(",")
        ]

        let request = Request(URL: URL, method: .GET, parameters: parameters, parse: {
            let tracks = $0.flatMap { return Track(JSON: $0) }
            if let tracks = tracks {
                return .Success(tracks)
            }
            return .Failure(GenericError)
            }, completion: { result, response in
                completion(SimpleAPIResponse(result))
        })
        request.start()
    }

    /**
    Search tracks that fit asked queries.
    
    - parameter queries:    The queries to run
    - parameter completion: The closure that will be called when tracks are loaded or upon error
    */
    public static func search(queries: [SearchQueryOptions], completion: PaginatedAPIResponse<Track> -> Void) {
        let URL = BaseURL
        var parameters = ["client_id": Soundcloud.clientIdentifier!, "linked_partitioning": "true"]
        queries.map { $0.query }.forEach { parameters[$0.0] = $0.1 }

        let parse = { (JSON: JSONObject) -> Result<[Track]> in
            let tracks = JSON.flatMap { return Track(JSON: $0) }
            if let tracks = tracks {
                return .Success(tracks)
            }
            return .Failure(GenericError)
        }

        let request = Request(URL: URL, method: .GET, parameters: parameters, parse: {
            return .Success(PaginatedAPIResponse(response: parse($0["collection"]), nextPageURL: $0["next_href"].URLValue, parse: parse))
            }, completion: { result, response in
                completion(result.result!)
        })
        request.start()
    }

    /**
    Load comments relative to a track

    - parameter completion: The closure that will be called when the comments are loaded or upon error
    */
    public func comments(completion: PaginatedAPIResponse<Comment> -> Void) {
        let URL = Track.BaseURL.URLByAppendingPathComponent("\(identifier)/comments.json")
        let parameters = ["client_id": Soundcloud.clientIdentifier!, "linked_partitioning": "true"]

        let parse = { (JSON: JSONObject) -> Result<[Comment]> in
            let comments = JSON.flatMap { return Comment(JSON: $0) }
            if let comments = comments {
                return .Success(comments)
            }
            return .Failure(GenericError)
        }

        let request = Request(URL: URL, method: .GET, parameters: parameters, parse: {
            return .Success(PaginatedAPIResponse(response: parse($0["collection"]), nextPageURL: $0["next_href"].URLValue, parse: parse))
            }, completion: { result, response in
                completion(result.result!)
        })
        request.start()
    }

    /**
    Create a new comment on a track
    
    **This method requires a Session.**

    - parameter body:       The text body of the comment
    - parameter timestamp:  The progression of the track when the comment was validated
    - parameter completion: The closure that will be called when the comment is posted or upon error
    */
    public func comment(body: String, timestamp: NSTimeInterval, completion: SimpleAPIResponse<Comment> -> Void) {
        if let oauthToken = Soundcloud.session?.accessToken {
            let URL = Track.BaseURL.URLByAppendingPathComponent("\(identifier)/comments.json")
            let parameters = ["client_id": Soundcloud.clientIdentifier!,
                "comment[body]": body,
                "comment[timestamp]": "\(timestamp)",
                "oauth_token": oauthToken
            ]

            let request = Request<Comment>(URL: URL, method: .POST, parameters: parameters, parse: {
                if let comments = Comment(JSON: $0) {
                    return .Success(comments)
                }
                return .Failure(GenericError)
            }, completion: { result, response in
                let r = SimpleAPIResponse(result)
                refreshTokenIfNecessaryCompletion(response, retry: {
                    self.comment(body, timestamp: timestamp, completion: completion)
                    }, completion: completion, result: r)
            })
            request.start()
        }
        else {
            completion(SimpleAPIResponse(.Failure(GenericError)))
        }
    }

    /**
    Fetch the list of users that favorited the track.

    - parameter completion: The closure that will be called when users are loaded or upon error
    */
    public func favoriters(completion: PaginatedAPIResponse<User> -> Void) {
        let URL = Track.BaseURL.URLByAppendingPathComponent("\(identifier)/favoriters.json")
        let parameters = ["client_id": Soundcloud.clientIdentifier!, "linked_partitioning": "true"]

        let parse = { (JSON: JSONObject) -> Result<[User]> in
            let users = JSON.flatMap { return User(JSON: $0) }
            if let users = users {
                return .Success(users)
            }
            return .Failure(GenericError)
        }

        let request = Request(URL: URL, method: .GET, parameters: parameters, parse: {
            return .Success(PaginatedAPIResponse(response: parse($0["collection"]), nextPageURL: $0["next_href"].URLValue, parse: parse))
            }, completion: { result, response in
                completion(result.result!)
        })
        request.start()
    }

    /**
    Favorites a track for the logged user
    
    **This method requires a Session.**

    - parameter userIdentifier: The identifier of the logged user
    - parameter completion:     The closure that will be called when the track has been favorited or upon error
    */
    public func favorite(userIdentifier: Int, completion: SimpleAPIResponse<Bool> -> Void) {
        if let oauthToken = Soundcloud.session?.accessToken {
            let baseURL = User.BaseURL.URLByAppendingPathComponent("\(userIdentifier)/favorites/\(identifier).json")
            let parameters = [
                "client_id": Soundcloud.clientIdentifier!,
                "oauth_token": oauthToken
            ]

            let URL = baseURL.URLByAppendingQueryString(parameters.queryString)
            let request = Request<Bool>(URL: URL, method: .PUT, parameters: nil, parse: {
                if let _ = $0["status"].stringValue?.rangeOfString(" OK") {
                    return .Success(true)
                }
                if let _ = $0["status"].stringValue?.rangeOfString(" Created") {
                    return .Success(true)
                }
                return .Failure(GenericError)
                }, completion: { result, response in
                    let r = SimpleAPIResponse(result)
                    refreshTokenIfNecessaryCompletion(response, retry: {
                        self.favorite(userIdentifier, completion: completion)
                        }, completion: completion, result: r)
            })
            request.start()
        }
        else {
            completion(SimpleAPIResponse(.Failure(GenericError)))
        }
    }
}
