{-# LANGUAGE LambdaCase, FlexibleInstances #-}
module Agda2Lambox.Convert.Term () where

import Control.Monad.Reader ( ask, liftIO )
import Data.List ( elemIndex )

import Utils

import Agda ( liftTCM, getConstructorData, getConstructors )
import qualified Agda as A
import Agda.Lib ()
import Agda.Utils
import Agda.Syntax.Literal
import Agda.Syntax.Abstract.Name ( QName(..), ModuleName(..) )
import Agda.Syntax.Common.Pretty ( prettyShow )

import LambdaBox
import qualified LambdaBox as L

import Agda2Lambox.Monad
import Agda2Lambox.Convert.Class


-- | Compiling (treeless) Agda terms into Lambox expressions.
instance A.TTerm ~> L.Term where
  go = \case
    A.TVar n   -> return $ LRel n
    A.TPrim pr -> go pr 
    A.TDef qn -> do
      Env{..} <- ask
      return case qn `elemIndex` mutuals of
        Nothing -> LVar (unqual qn)
        Just i  -> LRel (i + boundVars) -- NOTE(flupe): this looks fishy
                                         --              this isn't a (locally-bound) var
                                         --              but a constant?
    A.TApp t args -> do
      ct    <- go t
      cargs <- mapM go args
      return $ foldl LApp ct cargs
    A.TLam t -> inBoundVar $ LLam <$> go t
    A.TLit l -> go l
    A.TCon qn -> do
      dt   <- liftTCM $ getConstructorData qn
      ctrs <- liftTCM $ getConstructors dt
      Just i <- pure $ qn `elemIndex` ctrs
      return $ LCtor (L.Inductive (qnameToKerName dt) 0) i [] 
      -- TODO(flupe): I *think* constructors have to be fully-applied
      -- TODO(flupe): mutual inductives
    A.TLet tt tu -> LLet <$> go tt <*> inBoundVar (go tu)
    A.TCase n A.CaseInfo{..} tt talts ->
      case caseErased of
        A.Erased _    -> fail "Erased matches are not supported."
        A.NotErased _ -> do
          calts <- traverse go talts
          cind <- go caseType
          return $ LCase cind 0 (LRel n) calts
    A.TUnit -> return LBox
    A.TSort -> return LBox
    A.TErased -> return LBox
    A.TCoerce tt  -> fail "Coerces are not supported."
    A.TError terr -> fail "Errors are not supported."

instance A.TAlt ~> ([Name], L.Term) where
  go = \case
    A.TACon{..}   -> (take aArity $ repeat Anon,) <$> inBoundVars aArity (go aBody)
    A.TALit{..}   -> ([],)                        <$> go aBody
    A.TAGuard{..} -> fail "TAGuard"

instance A.CaseType ~> L.Inductive where
  go = \case
    A.CTData qn -> return $ L.Inductive (qnameToKerName qn) 0 
                   -- TODO(flupe): handle mutual inductive
    _           -> fail "Not supported case type"

-- TODO(flupe): handle using MetaCoq tPrim and prim_val
instance A.Literal ~> L.Term where
  go = \case
    LitNat    n -> fail "Literal natural numbers not supported"
    LitWord64 w -> fail "Literal int64 not supported"
    LitFloat  f -> fail "Literal float not supported"
    LitString s -> fail "Literal string not supported"
    LitChar   c -> fail "Literal char not supported"
    _           -> fail "Literal not supported"

instance A.TPrim ~> L.Term where
  go = const $ fail "unsupported prim"
