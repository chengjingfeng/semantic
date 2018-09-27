{-# LANGUAGE GADTs, RankNTypes #-}
module Semantic.Parse ( runParse, runParse', parseSomeBlob ) where

import           Analysis.ConstructorName (ConstructorName)
import           Analysis.Declaration (HasDeclaration, declarationAlgebra)
import           Analysis.PackageDef (HasPackageDef)
import           Control.Monad.Effect.Exception
import           Data.Blob
import           Data.Graph.TermVertex
import           Data.JSON.Fields
import           Data.Quieterm
import           Data.Location
import           Data.Term
import           Parsing.Parser
import           Prologue hiding (MonadError (..))
import           Rendering.Graph
import           Rendering.JSON (SomeJSON (..))
import qualified Rendering.JSON as JSON
import           Rendering.Renderer
import           Semantic.IO (noLanguageForBlob)
import           Semantic.Task
import           Serializing.Format

-- | Using the specified renderer, parse a list of 'Blob's to produce a 'Builder' output.
runParse :: (Member Distribute effs, Member (Exc SomeException) effs, Member Task effs) => TermRenderer output -> [Blob] -> Eff effs Builder
runParse JSONTermRenderer             = withParsedBlobs' renderJSONError (render . renderJSONTerm) >=> serialize JSON
runParse JSONGraphTermRenderer        = withParsedBlobs' renderJSONError (render . renderAdjGraph) >=> serialize JSON
  where renderAdjGraph :: (Recursive t, ToTreeGraph TermVertex (Base t)) => Blob -> t -> JSON.JSON "trees" SomeJSON
        renderAdjGraph blob term = renderJSONAdjTerm blob (renderTreeGraph term)
runParse SExpressionTermRenderer      = withParsedBlobs (const (serialize (SExpression ByConstructorName)))
runParse ShowTermRenderer             = withParsedBlobs (const (serialize Show . quieterm))
runParse (SymbolsTermRenderer fields) = withParsedBlobs (\ blob -> decorate (declarationAlgebra blob) >=> render (renderSymbolTerms . renderToSymbols fields blob)) >=> serialize JSON
runParse DOTTermRenderer              = withParsedBlobs (const (render renderTreeGraph)) >=> serialize (DOT (termStyle "terms"))

-- | For testing and running parse-examples.
runParse' :: (Member (Exc SomeException) effs, Member Task effs) => Blob -> Eff effs Builder
runParse' blob = parseSomeBlob blob >>= withSomeTerm (serialize Show . quieterm)

type Render effs output = forall syntax .
  ( ConstructorName syntax
  , HasDeclaration syntax
  , HasPackageDef syntax
  , Foldable syntax
  , Functor syntax
  , Show1 syntax
  , ToJSONFields1 syntax
  )
  => Blob -> Term syntax Location -> Eff effs output

withParsedBlobs :: (Member Distribute effs, Member (Exc SomeException) effs, Member Task effs, Monoid output)
  => Render effs output -> [Blob] -> Eff effs output
withParsedBlobs render = distributeFoldMap $ \blob -> parseSomeBlob blob >>= withSomeTerm (render blob)

withParsedBlobs' :: (Member Distribute effs, Member (Exc SomeException) effs, Member Task effs, Monoid output)
  => (Blob -> String -> output) -> Render effs output -> [Blob] -> Eff effs output
withParsedBlobs' onError render = distributeFoldMap $ \blob ->
  (parseSomeBlob blob >>= withSomeTerm (render blob)) `catchError` \(SomeException e) ->
    pure (onError blob (show e))

parseSomeBlob :: (Member (Exc SomeException) effs, Member Task effs) => Blob -> Eff effs (SomeTerm '[ConstructorName, Foldable, Functor, HasDeclaration, HasPackageDef, Show1, ToJSONFields1] Location)
parseSomeBlob blob@Blob{..} = maybe (noLanguageForBlob blobPath) (`parse` blob) (someParser blobLanguage)
