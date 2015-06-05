{-# LANGUAGE OverloadedStrings #-}
module Databrary.Controller.Permission
  ( checkPermission
  , checkDataPermission
  , authAccount
  , checkVerfHeader
  , guardVerfHeader
  ) where

import Control.Monad (liftM2)
import Control.Monad.IO.Class (MonadIO)
import qualified Data.Foldable as Fold

import Databrary.Has (Has, view, peek, peeks)
import Databrary.Model.Permission
import Databrary.Model.Release
import Databrary.Model.Party
import Databrary.Model.Identity
import Databrary.HTTP.Request
import Databrary.Action

checkPermission :: (MonadAction c m, MonadIO m, Has Permission a) => Permission -> a -> m a
checkPermission p o = do
  guardAction (view o >= p) forbiddenResponse
  return o

checkDataPermission :: (MonadAction c m, MonadIO m, Has Release a, Has Permission a) => a -> m a
checkDataPermission o = do
  guardAction (dataPermission o > PermissionNONE) forbiddenResponse
  return o

authAccount :: AuthActionM Account
authAccount = do
  ident <- peek
  case ident of
    UnIdentified -> result =<< forbiddenResponse
    Identified s -> return $ view s
    ReIdentified u -> return $ view u

checkVerfHeader :: (MonadAuthAction q m) => m Bool
checkVerfHeader = do
  header <- peeks $ lookupRequestHeader "x-csverf"
  peeks $ Fold.or . liftM2 (==) header . identityVerf

guardVerfHeader :: AuthActionM ()
guardVerfHeader = do
  c <- checkVerfHeader
  guardAction c forbiddenResponse
