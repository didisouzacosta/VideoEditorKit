//
//  AudioEntity+Ext.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import CoreData


extension AudioEntity{
    
    
    var audioModel: Audio?{
        guard let urlStr = url, let url = URL(string: urlStr) else { return nil }
        return .init(url: url, duration: duration)
    }
    
    static func createAudio(context: NSManagedObjectContext, url: String, duration: Double) -> AudioEntity{
        let entity = AudioEntity(context: context)
        entity.duration = duration
        entity.url = url
        return entity
    }
}
