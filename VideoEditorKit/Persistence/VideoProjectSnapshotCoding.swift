import Foundation

protocol VideoProjectSnapshotCoding {
    func makeSnapshot(from project: VideoProject) throws -> VideoProjectSnapshot
    func makeProject(from snapshot: VideoProjectSnapshot) throws -> VideoProject
}
