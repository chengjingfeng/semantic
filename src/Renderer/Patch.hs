  hunks,
  Hunk(..)
header blobs hunk = intercalate "\n" [filepathHeader, fileModeHeader, beforeFilepath, afterFilepath, maybeOffsetHeader]
  where filepathHeader = "diff --git a/" ++ pathA ++ " b/" ++ pathB
        fileModeHeader = case (modeA, modeB) of
          (Nothing, Just mode) -> intercalate "\n" [ "new file mode " ++ modeToDigits mode, blobOidHeader ]
          (Just mode, Nothing) -> intercalate "\n" [ "old file mode " ++ modeToDigits mode, blobOidHeader ]
          (Just mode, Just other) | mode == other -> "index " ++ oidA ++ ".." ++ oidB ++ " " ++ modeToDigits mode
          (Just mode1, Just mode2) -> intercalate "\n" [
            "old mode" ++ modeToDigits mode1,
            "new mode " ++ modeToDigits mode2 ++ " " ++ blobOidHeader
            ]
          (Nothing, Nothing) -> ""
        blobOidHeader = "index " ++ oidA ++ ".." ++ oidB
        modeHeader :: String -> Maybe SourceKind -> String -> String
        modeHeader ty maybeMode path = case maybeMode of
           Just _ -> ty ++ "/" ++ path
           Nothing -> "/dev/null"
        beforeFilepath = "--- " ++ modeHeader "a" modeA pathA
        afterFilepath = "+++ " ++ modeHeader "b" modeB pathB
        maybeOffsetHeader = if lengthA > 0 && lengthB > 0
                            then offsetHeader
                            else mempty
        offsetHeader = "@@ -" ++ offsetA ++ "," ++ show lengthA ++ " +" ++ offsetB ++ "," ++ show lengthB ++ " @@" ++ "\n"
        (lengthA, lengthB) = runBoth . fmap getSum $ hunkLength hunk
        (offsetA, offsetB) = runBoth . fmap (show . getSum) $ offset hunk
        (modeA, modeB) = runBoth $ blobKind <$> blobs
hunks _ blobs | Both (True, True) <- Source.null . source <$> blobs = [Hunk { offset = mempty, changes = [], trailingContext = [] }]
hunks diff blobs = hunksInRows (Both (1, 1)) $ fmap Prelude.fst <$> splitDiffByLines (source <$> blobs) diff