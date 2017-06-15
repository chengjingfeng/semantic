module CommandSpec where

import Command
import Data.Functor.Both as Both
import Data.Maybe
import Data.String
import Language
import Prologue hiding (readFile, toList)
import Source
import Test.Hspec hiding (shouldBe, shouldNotBe, shouldThrow, errorCall)
import Test.Hspec.Expectations.Pretty

spec :: Spec
spec = parallel $ do
  describe "readFile" $ do
    it "returns a blob for extant files" $ do
      blob <- runCommand (readFile "semantic-diff.cabal" Nothing)
      path blob `shouldBe` "semantic-diff.cabal"

    it "returns a nullBlob for absent files" $ do
      blob <- runCommand (readFile "this file should not exist" Nothing)
      nullBlob blob `shouldBe` True

  describe "readBlobPairsFromHandle" $ do
    let a = sourceBlob "method.rb" (Just Ruby) "def foo; end"
    let b = sourceBlob "method.rb" (Just Ruby) "def bar(x); end"
    it "returns blobs for valid JSON encoded diff input" $ do
      blobs <- blobsFromFilePath "test/fixtures/input/diff.json"
      blobs `shouldBe` [both a b]

    it "returns blobs when there's no before" $ do
      blobs <- blobsFromFilePath "test/fixtures/input/diff-no-before.json"
      blobs `shouldBe` [both (emptySourceBlob "method.rb") b]

    it "returns blobs when there's null before" $ do
      blobs <- blobsFromFilePath "test/fixtures/input/diff-null-before.json"
      blobs `shouldBe` [both (emptySourceBlob "method.rb") b]

    it "returns blobs when there's no after" $ do
      blobs <- blobsFromFilePath "test/fixtures/input/diff-no-after.json"
      blobs `shouldBe` [both a (emptySourceBlob "method.rb")]

    it "returns blobs when there's null after" $ do
      blobs <- blobsFromFilePath "test/fixtures/input/diff-null-after.json"
      blobs `shouldBe` [both a (emptySourceBlob "method.rb")]


    it "returns blobs for unsupported language" $ do
      h <- openFile "test/fixtures/input/diff-unsupported-language.json" ReadMode
      blobs <- runCommand (readBlobPairsFromHandle h)
      let b' = sourceBlob "test.kt" Nothing "fun main(args: Array<String>) {\nprintln(\"hi\")\n}\n"
      blobs `shouldBe` [both (emptySourceBlob "test.kt") b']

    it "detects language based on filepath for empty language" $ do
      blobs <- blobsFromFilePath "test/fixtures/input/diff-empty-language.json"
      blobs `shouldBe` [both a b]

    it "throws on blank input" $ do
      h <- openFile "test/fixtures/input/blank.json" ReadMode
      runCommand (readBlobPairsFromHandle h) `shouldThrow` (== ExitFailure 1)

    it "throws if language field not given" $ do
      h <- openFile "test/fixtures/input/diff-no-language.json" ReadMode
      runCommand (readBlobsFromHandle h) `shouldThrow` (== ExitFailure 1)

  describe "readBlobsFromHandle" $ do
    it "returns blobs for valid JSON encoded parse input" $ do
      h <- openFile "test/fixtures/input/parse.json" ReadMode
      blobs <- runCommand (readBlobsFromHandle h)
      let a = sourceBlob "method.rb" (Just Ruby) "def foo; end"
      blobs `shouldBe` [a]

    it "throws on blank input" $ do
      h <- openFile "test/fixtures/input/blank.json" ReadMode
      runCommand (readBlobsFromHandle h) `shouldThrow` (== ExitFailure 1)

  where blobsFromFilePath path = do
          h <- openFile path ReadMode
          blobs <- runCommand (readBlobPairsFromHandle h)
          pure blobs

data Fixture = Fixture { shas :: Both String, expectedBlobs :: [Both SourceBlob] }
