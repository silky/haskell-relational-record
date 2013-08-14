{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- |
-- Module      : Database.Relational.Query.Monad.Trans.Restrict
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines monad transformer which lift to basic 'MonadQuery'.
module Database.Relational.Query.Monad.Trans.Restrict (
  -- * Transformer into restricted context
  Restrict, restrict,

  -- * Result SQL wheres clause
  extractWheres,
  WhereAppend, appendWhere
  ) where

import Control.Monad.Trans.Class (MonadTrans (lift))
import Control.Monad.Trans.State (modify, StateT, runStateT)
import Control.Applicative (Applicative, (<$>))
import Control.Arrow (second)

import Database.Relational.Query.Monad.Trans.StateAppend (Append, append, liftToString)
import Database.Relational.Query.Monad.Trans.RestrictState
  (RestrictContext, primeRestrictContext, addRestriction, composeWheres)
import Database.Relational.Query.Projection (Projection)
import Database.Relational.Query.Expr (Expr)

import Database.Relational.Query.Monad.Class (MonadRestrict(..), MonadQuery (..))


-- | 'StateT' type to accumulate join product context.
newtype Restrict m a =
  Restrict { queryState :: StateT RestrictContext m a }
  deriving (MonadTrans, Monad, Functor, Applicative)

-- | Run 'Restrict' to expand context state.
runRestrict :: Restrict m a  -- ^ RestrictContext to expand
             -> RestrictContext        -- ^ Initial context
             -> m (a, RestrictContext) -- ^ Expanded result
runRestrict =  runStateT . queryState

-- | Run 'Restrict' with primary empty context to expand context state.
runRestrictPrime :: Restrict m a           -- ^ RestrictContext to expand
                 -> m (a, RestrictContext) -- ^ Expanded result
runRestrictPrime q = runRestrict q primeRestrictContext

-- | Lift to 'Restrict'
restrict :: Monad m => m a -> Restrict m a
restrict =  lift

-- | Unsafely update join product context.
updateRestrictContext :: Monad m => (RestrictContext -> RestrictContext) -> Restrict m ()
updateRestrictContext =  Restrict . modify

-- | Add whole query restriction.
updateRestriction :: Monad m => Expr Projection (Maybe Bool) -> Restrict m ()
updateRestriction e = updateRestrictContext (addRestriction e)

-- | 'MonadRestrict' instance.
instance (Monad q, Functor q) => MonadRestrict (Restrict q) where
  restrictContext = updateRestriction

-- | Restricted 'MonadQuery' instance.
instance MonadQuery q => MonadQuery (Restrict q) where
  restrictJoin     = restrict . restrictJoin
  unsafeSubQuery a = restrict . unsafeSubQuery a

-- | WHERE clause appending function.
type WhereAppend = Append RestrictContext

-- | Run 'Restricts' to get WHERE clause appending function.
extractWheres :: (Monad m, Functor m)
              => Restrict m a         -- ^ 'Restrict' to run
              -> m (a,  WhereAppend) -- ^ WHERE clause appending function.
extractWheres r = second (liftToString composeWheres) <$> runRestrictPrime r

-- | Run WHERE clause append.
appendWhere :: WhereAppend -> String -> String
appendWhere =  append