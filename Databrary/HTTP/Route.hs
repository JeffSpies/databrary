{-# LANGUAGE ExistentialQuantification, RecordWildCards, ImpredicativeTypes #-}
module Databrary.HTTP.Route
  ( Route(..)
  , route
  , RouteMap
  , fromRouteList
  , lookupRoute
  , routeURL
  ) where

import Prelude hiding (lookup)

import Control.Applicative ((<$>))
import qualified Data.ByteString.Builder as BSB
import qualified Data.HashMap.Strict as HM
import Data.List (foldl')
import Data.Monoid ((<>))
import Network.HTTP.Types (Method)
import qualified Network.Wai as Wai

import Databrary.Iso.Types (Invariant(..))
import Databrary.HTTP.Request
import Databrary.HTTP.Path.Types
import qualified Databrary.HTTP.Path.Map as PM
import Databrary.HTTP.Path.Parser

data Route r a = Route
  { routeMethod :: !Method
  , routeMultipart :: !Bool
  , routePath :: PathParser a
  , routeAction :: a -> r
  }

instance Invariant (Route r) where
  invMap f g r = r
    { routePath = invMap f g $ routePath r
    , routeAction = routeAction r . g
    }

-- these should never actually return Nothing...
type RouteResult r = PathResult -> Maybe r

data RouteCase r = RouteCase
  { _routeMethod :: !Method
  , _routeElements :: [PathElement]
  , _routeResult :: RouteResult r
  }

route :: Route r a -> [RouteCase r]
route Route{ routeMethod = m, routePath = p, routeAction = f } = cf <$> pathCases p where
  cf (e, rf) = RouteCase m e $ \r -> do
    (v, PathResultNull) <- rf r
    return $ f v

newtype RouteMap r = RouteMap (HM.HashMap Method (PM.PathMap (RouteResult r)))

empty :: RouteMap a
empty = RouteMap HM.empty

insert :: RouteCase r -> RouteMap r -> RouteMap r
insert (RouteCase a p r) (RouteMap m) = RouteMap $
  HM.insertWith (const $ PM.insert p r) a (PM.singleton p r) m

fromRouteList :: [[RouteCase r]] -> RouteMap r
fromRouteList = foldl' (flip insert) empty . concat

lookupRoute :: Wai.Request -> RouteMap r -> Maybe r
lookupRoute q (RouteMap m) =
  uncurry (flip ($)) =<< PM.lookup (Wai.pathInfo q) =<< HM.lookup (Wai.requestMethod q) m

routeURL :: Maybe Wai.Request -> Route r a -> a -> BSB.Builder
routeURL req Route{ routePath = p } a =
  maybe id ((<>) . BSB.byteString . requestHost) req $ renderPath $ pathGenerate p a
