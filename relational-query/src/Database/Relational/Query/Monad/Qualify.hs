{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- |
-- Module      : Database.Relational.Query.Monad.Qualify
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines monad structure to qualify uniquely SQL table forms.
module Database.Relational.Query.Monad.Qualify (
  -- * Qualify monad
  Qualify,
  evalQualifyPrime, qualifyQuery
  ) where

import Control.Monad.Trans.State (StateT, runStateT, get, modify)
import Control.Applicative (Applicative)
import Control.Monad (liftM)

import Database.Relational.Query.Sub (Qualified)
import qualified Database.Relational.Query.Sub as SubQuery


type AliasId = Int

-- | Monad type to qualify SQL table forms.
newtype Qualify m a =
  Qualify (StateT AliasId m a)
  deriving (Monad, Functor, Applicative)

-- | Run qualify monad with initial state to get only result.
evalQualifyPrime :: Monad m => Qualify m a -> m a
evalQualifyPrime (Qualify s) = fst `liftM` runStateT s 0 {- primary alias id -}

-- | Generated new qualifier on internal state.
newAlias :: Monad m => Qualify m AliasId
newAlias =  Qualify $ do
  ai <- get
  modify (+ 1)
  return ai

-- | Get qualifyed table form query.
qualifyQuery :: Monad m
             => query                       -- ^ Query to qualify
             -> Qualify m (Qualified query) -- ^ Result with updated state
qualifyQuery query =
  do n <- newAlias
     return . SubQuery.qualify query $ SubQuery.Qualifier n
