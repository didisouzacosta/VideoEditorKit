//
//  RootViewModel.swift
//  VideoEditorKit
//
//  Created by Adriano Souza Costa on 23.03.2026.
//

import Foundation
import CoreData
import Observation

@MainActor
@Observable
final class RootViewModel {
    var projects = [ProjectEntity]()

    private let dataManager: CoreDataManager
    
    init(mainContext: NSManagedObjectContext){
        self.dataManager = CoreDataManager(mainContext: mainContext)
    }
    
    func fetch(){
        projects = dataManager.fetchProjects()
    }
    
    func removeProject(_ project: ProjectEntity){
        ProjectEntity.remove(project)
        fetch()
    }
}
