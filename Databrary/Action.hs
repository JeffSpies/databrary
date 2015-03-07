{-# LANGUAGE OverloadedStrings #-}
module Databrary.Action
  ( Request
  , Action
  , MonadAction
  , AppAction
  , AppRequest
  , AuthAction
  , AuthRequest

  , Response
  , returnResponse
  , emptyResponse
  , redirectRouteResponse
  , forbiddenResponse
  , notFoundResponse
  , okResponse
  , result
  , guardAction
  , maybeAction

  , StdMethod(GET, POST)
  , RouteAction(..)
  , API(..)
  , actionURL
  , AppRAction
  , AuthRAction
  , action
  , withAuth

  , runAppRoute
  ) where

import qualified Blaze.ByteString.Builder as Blaze
import Control.Monad.IO.Class (MonadIO)
import Data.Maybe (fromMaybe)
import Data.Monoid (mempty)
import Network.HTTP.Types (Status, ok200, seeOther303, forbidden403, notFound404, ResponseHeaders, hLocation)
import qualified Network.Wai as Wai

import Control.Has (peek, peeks)
import Databrary.Web.Request
import Databrary.Action.Types
import Databrary.Action.Response
import Databrary.Action.App
import Databrary.Action.Auth
import Databrary.Action.Route
import Databrary.Resource
import qualified Databrary.Web.Route as R

emptyResponse :: MonadAction q m => Status -> ResponseHeaders -> m Response
emptyResponse s h = returnResponse s h (mempty :: Blaze.Builder)

redirectRouteResponse :: MonadAction q m => ResponseHeaders -> RouteAction qa -> m Response
redirectRouteResponse h a = do
  url <- peeks $ actionURL a
  emptyResponse seeOther303 ((hLocation, url) : h)

forbiddenResponse :: MonadAction q m => m Response
forbiddenResponse = emptyResponse forbidden403 []

notFoundResponse :: MonadAction q m => m Response
notFoundResponse = emptyResponse notFound404 []

okResponse :: (MonadAction q m, ResponseData r) => ResponseHeaders -> r -> m Response
okResponse = returnResponse ok200

guardAction :: (MonadAction q m, MonadIO m) => Bool -> m Response -> m ()
guardAction True _ = return ()
guardAction False r = result =<< r

maybeAction :: (MonadAction q m, MonadIO m) => Maybe a -> m a
maybeAction (Just a) = return a
maybeAction Nothing = result =<< notFoundResponse

type AppRAction = RouteAction AppRequest
type AuthRAction = RouteAction AuthRequest

runAppRoute :: R.RouteM AppAction -> Resource -> Wai.Application
runAppRoute route rc = runApp rc $
  fromMaybe notFoundResponse . R.routeRequest route =<< peek
