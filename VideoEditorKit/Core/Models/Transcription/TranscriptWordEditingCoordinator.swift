//
//  TranscriptWordEditingCoordinator.swift
//  VideoEditorKit
//
//  Created by Codex on 07.04.2026.
//

import Foundation

enum TranscriptWordEditingCoordinator {

    private struct TokenMatch: Equatable {

        // MARK: - Public Properties

        let wordIndex: Int
        let tokenIndex: Int

    }

    // MARK: - Public Methods

    static func reconcileWords(
        _ words: [EditableTranscriptWord],
        with editedSegmentText: String
    ) -> [EditableTranscriptWord]? {
        let tokens = mergedWordTokens(
            from: editedSegmentText
        )

        guard tokens.isEmpty == false else { return nil }

        if tokens.count == words.count {
            return wordsUpdated(
                from: words,
                with: tokens
            )
        }

        let anchorTokens = words.map(\.originalText).map(normalizedAnchorToken)
        let tokenKeys = tokens.map(normalizedAnchorToken)
        let matches = longestCommonSubsequence(
            wordAnchors: anchorTokens,
            tokenAnchors: tokenKeys
        )

        switch tokens.count {
        case ..<words.count:
            guard matches.count == tokens.count else { return nil }
        case (words.count + 1)...:
            guard matches.count == words.count else { return nil }
        default:
            break
        }

        let groupedTokens = groupedTokens(
            tokens: tokens,
            words: words,
            matches: matches
        )

        return wordsUpdated(
            from: words,
            with: groupedTokens
        )
    }

    // MARK: - Private Methods

    private static func wordsUpdated(
        from words: [EditableTranscriptWord],
        with tokens: [String]
    ) -> [EditableTranscriptWord]? {
        guard tokens.count == words.count else { return nil }

        return zip(words, tokens).map { word, token in
            var updatedWord = word
            updatedWord.editedText = token
            return updatedWord
        }
    }

    private static func mergedWordTokens(
        from text: String
    ) -> [String] {
        let rawTokens =
            text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }

        var mergedTokens = [String]()
        var pendingPrefix = ""

        for rawToken in rawTokens {
            if rawToken.containsWordCharacters {
                mergedTokens.append(pendingPrefix + rawToken)
                pendingPrefix = ""
                continue
            }

            if let lastIndex = mergedTokens.indices.last {
                mergedTokens[lastIndex].append(rawToken)
            } else {
                pendingPrefix.append(rawToken)
            }
        }

        if pendingPrefix.isEmpty == false, let firstIndex = mergedTokens.indices.first {
            mergedTokens[firstIndex] = pendingPrefix + mergedTokens[firstIndex]
        }

        return mergedTokens
    }

    private static func normalizedAnchorToken(
        _ text: String
    ) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    private static func longestCommonSubsequence(
        wordAnchors: [String],
        tokenAnchors: [String]
    ) -> [TokenMatch] {
        guard wordAnchors.isEmpty == false, tokenAnchors.isEmpty == false else { return [] }

        let rowCount = wordAnchors.count + 1
        let columnCount = tokenAnchors.count + 1
        var lengths = Array(
            repeating: Array(repeating: 0, count: columnCount),
            count: rowCount
        )

        for wordIndex in wordAnchors.indices {
            for tokenIndex in tokenAnchors.indices {
                if wordAnchors[wordIndex].isEmpty == false,
                    wordAnchors[wordIndex] == tokenAnchors[tokenIndex]
                {
                    lengths[wordIndex + 1][tokenIndex + 1] =
                        lengths[wordIndex][tokenIndex] + 1
                } else {
                    lengths[wordIndex + 1][tokenIndex + 1] = max(
                        lengths[wordIndex][tokenIndex + 1],
                        lengths[wordIndex + 1][tokenIndex]
                    )
                }
            }
        }

        var matches = [TokenMatch]()
        var wordCursor = wordAnchors.count
        var tokenCursor = tokenAnchors.count

        while wordCursor > 0, tokenCursor > 0 {
            if wordAnchors[wordCursor - 1].isEmpty == false,
                wordAnchors[wordCursor - 1] == tokenAnchors[tokenCursor - 1]
            {
                matches.append(
                    TokenMatch(
                        wordIndex: wordCursor - 1,
                        tokenIndex: tokenCursor - 1
                    )
                )
                wordCursor -= 1
                tokenCursor -= 1
            } else if lengths[wordCursor - 1][tokenCursor] >= lengths[wordCursor][tokenCursor - 1] {
                wordCursor -= 1
            } else {
                tokenCursor -= 1
            }
        }

        return matches.reversed()
    }

    private static func groupedTokens(
        tokens: [String],
        words: [EditableTranscriptWord],
        matches: [TokenMatch]
    ) -> [String] {
        var groupedTokens = Array(
            repeating: "",
            count: words.count
        )
        let matchesByWordIndex = Dictionary(
            uniqueKeysWithValues: matches.map { ($0.wordIndex, $0.tokenIndex) }
        )
        let sortedMatches = matches.sorted { lhs, rhs in
            lhs.wordIndex < rhs.wordIndex
        }

        for wordIndex in words.indices {
            guard let matchedTokenIndex = matchesByWordIndex[wordIndex] else { continue }

            let nextMatchTokenIndex =
                sortedMatches
                .first(where: { $0.wordIndex > wordIndex })?
                .tokenIndex
                ?? tokens.count

            groupedTokens[wordIndex] = tokens[matchedTokenIndex..<nextMatchTokenIndex]
                .joined(separator: " ")
        }

        if let firstMatchedWordIndex = sortedMatches.first?.wordIndex,
            let firstMatchedTokenIndex = sortedMatches.first?.tokenIndex,
            firstMatchedTokenIndex > 0
        {
            let leadingText = tokens[..<firstMatchedTokenIndex].joined(separator: " ")
            groupedTokens[firstMatchedWordIndex] = leadingText + " " + groupedTokens[firstMatchedWordIndex]
        }

        return groupedTokens.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

}

extension String {

    // MARK: - Private Properties

    fileprivate var containsWordCharacters: Bool {
        rangeOfCharacter(from: .alphanumerics) != nil
    }

}
