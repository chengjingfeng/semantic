import Info
import Data.Functor.Both as Both
import Data.List
patch diff blobs = case getLast $ foldMap (Last . Just) string of
  Just c | c /= '\n' -> string ++ "\n\\ No newline at end of file\n"
  _ -> string
  where string = header blobs ++ mconcat (showHunk blobs <$> hunks diff blobs)
hunkLength hunk = mconcat $ (changeLength <$> changes hunk) <> (rowIncrement <$> trailingContext hunk)
changeLength change = mconcat $ (rowIncrement <$> context change) <> (rowIncrement <$> contents change)
-- | The increment the given row implies for line numbering.
rowIncrement :: Row a -> Both (Sum Int)
rowIncrement = fmap lineIncrement
showHunk blobs hunk = maybeOffsetHeader ++
  concat (showChange sources <$> changes hunk) ++
  showLines (snd sources) ' ' (snd <$> trailingContext hunk)
        maybeOffsetHeader = if lengthA > 0 && lengthB > 0
                            then offsetHeader
                            else mempty
        offsetHeader = "@@ -" ++ offsetA ++ "," ++ show lengthA ++ " +" ++ offsetB ++ "," ++ show lengthB ++ " @@" ++ "\n"
        (lengthA, lengthB) = runBoth . fmap getSum $ hunkLength hunk
        (offsetA, offsetB) = runBoth . fmap (show . getSum) $ offset hunk
showChange sources change = showLines (snd sources) ' ' (snd <$> context change) ++ deleted ++ inserted
  where (deleted, inserted) = runBoth $ pure showLines <*> sources <*> Both ('-', '+') <*> Both.unzip (contents change)
showLine source line | isEmpty line = Nothing
                     | otherwise = Just . toString . (`slice` source) . unionRanges $ getRange <$> unLine line
header :: Both SourceBlob -> String
header blobs = intercalate "\n" [filepathHeader, fileModeHeader, beforeFilepath, afterFilepath] ++ "\n"
          (Just mode, Nothing) -> intercalate "\n" [ "deleted file mode " ++ modeToDigits mode, blobOidHeader ]
            "old mode " ++ modeToDigits mode1,
            "new mode " ++ modeToDigits mode2,
            blobOidHeader
hunks _ blobs | sources <- source <$> blobs
              , sourcesEqual <- runBothWith (==) sources
              , sourcesNull <- runBothWith (&&) (null <$> sources)
              , sourcesEqual || sourcesNull
  = [Hunk { offset = mempty, changes = [], trailingContext = [] }]
hunks diff blobs = hunksInRows (Both (1, 1)) $ fmap (fmap Prelude.fst) <$> splitDiffByLines (source <$> blobs) diff
  Just (change, afterChanges) -> Just (start <> mconcat (rowIncrement <$> skippedContext), change, afterChanges)
rowHasChanges lines = or (lineHasChanges <$> lines)