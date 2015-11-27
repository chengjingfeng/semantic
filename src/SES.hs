module SES where

import Patch
import Diff
import Term
import Control.Monad.Free
import Data.Foldable (minimumBy)
import Data.Ord (comparing)

type Compare a annotation = Term a annotation -> Term a annotation -> Maybe (Diff a annotation)
type Cost a annotation = Diff a annotation -> Integer

ses :: Compare a annotation -> Cost a annotation -> [Term a annotation] -> [Term a annotation] -> [Diff a annotation]
ses _ _ [] b = (Pure . Insert) <$> b
ses _ _ a [] = (Pure . Delete) <$> a
ses diffTerms cost (a : as) (b : bs) = case diffTerms a b of
  Just f -> minimumBy (comparing sumCost) [ delete, insert, copy f ]
  Nothing -> minimumBy (comparing sumCost) [ delete, insert ]
  where
    delete = (Pure . Delete $ a) : ses diffTerms cost as (b : bs)
    insert = (Pure . Insert $ b) : ses diffTerms cost (a : as) bs
    sumCost script = sum $ cost <$> script
    copy head = head : ses diffTerms cost as bs
