{-# LANGUAGE FlexibleInstances, FlexibleContexts, OverloadedStrings #-}
module Databrary.Snaplet.PG (
  -- * The Snaplet
    PG(..)
  , HasPG(..)
  , PGConfig(..)
  , pgDefaultConfig

  , pgInit
  , pgInit'

  , getPGConfig
  , getPGDatabase
  , loadPGDatabase
  , withPG
  , liftPG

  , PG.pgSQL
  , pgRunQuery
  , pgExecute
  , pgExecute1
  , pgQuery
  , pgQuery1

  , useTPG
  ) where

import Control.Applicative ((<$>))
import Control.Lens (set, (^#))
import Control.Monad (when)
import Control.Monad.CatchIO (MonadCatchIO)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.State (get)
import Control.Monad.Reader (ReaderT, local, ask, asks)
import qualified Data.Configurator as C
import qualified Data.Configurator.Types as C
import Data.IORef (IORef, newIORef, atomicModifyIORef')
import Data.Pool (Pool, withResource, createPool)
import Data.Sequence (Seq)
import qualified Language.Haskell.TH as TH
import Network (PortID(..))
import Snap.Snaplet
import System.IO.Unsafe (unsafePerformIO)

import qualified Database.PostgreSQL.Typed as PG
import qualified Database.PostgreSQL.Typed.Query as PG
import Paths_databrary (getDataDir)


data PG
  = PGPool (Pool PG.PGConnection)
  | PGConn PG.PGConnection

class (MonadCatchIO m) => HasPG m where
  getPGState :: m PG
  setLocalPGState :: PG -> m a -> m a

instance HasPG (Handler b PG) where
  getPGState = get
  setLocalPGState s = local (const s)

instance (MonadCatchIO m) => HasPG (ReaderT (Snaplet PG) m) where
  getPGState = asks (^# snapletValue)
  setLocalPGState s = local (set snapletValue s)

instance (MonadCatchIO m) => HasPG (ReaderT PG m) where
  getPGState = ask
  setLocalPGState s = local (const s)

withPG :: HasPG m => m b -> m b
withPG f = do
  s <- getPGState
  case s of
    PGPool p -> withResource p (\c -> setLocalPGState (PGConn c) f)
    PGConn _ -> f

liftPG :: HasPG m => (PG.PGConnection -> IO a) -> m a
liftPG f = do
  s <- getPGState
  liftPG' s f

liftPG' :: MonadIO m => PG -> (PG.PGConnection -> IO a) -> m a
liftPG' (PGPool p) f = liftIO (withResource p f)
liftPG' (PGConn c) f = liftIO (f c)

data PGConfig = PGConfig
  { pgConfigDatabase :: PG.PGDatabase
  , pgConfigNumStripes :: Int
  , pgConfigIdleTime :: Double
  , pgConfigResources :: Int
  }

pgDefaultConfig :: PG.PGDatabase -> PGConfig
pgDefaultConfig db = PGConfig db 1 60 16

getPGDatabase :: C.Config -> IO PG.PGDatabase
getPGDatabase config = do
  host <- C.lookupDefault "localhost" config "host"
  port <- C.lookupDefault (5432 :: Int) config "port"
  sock <- C.lookup config "sock"
  user <- C.require config "user"
  db <- C.lookupDefault user config "db"
  passwd <- C.lookupDefault "" config "pass"
  debug <- C.lookupDefault False config "debug"
  return $ PG.PGDatabase
    { PG.pgDBHost = host
    , PG.pgDBPort = maybe (PortNumber (fromIntegral port)) UnixSocket sock
    , PG.pgDBName = db
    , PG.pgDBUser = user
    , PG.pgDBPass = passwd
    , PG.pgDBDebug = debug
    , PG.pgDBLogMessage = \_ -> return () -- something better?
    }

-- |Suitable for use with 'useTPGDatabase'
loadPGDatabase :: FilePath -> IO PG.PGDatabase
loadPGDatabase f = getPGDatabase =<< C.load [C.Required f]

getPGConfig :: C.Config -> IO PGConfig
getPGConfig config = do
  db <- getPGDatabase config
  let def = pgDefaultConfig db
  stripes <- C.lookupDefault (pgConfigNumStripes def) config "numStripes"
  idle <- C.lookupDefault (pgConfigIdleTime def) config "idleTime"
  resources <- C.lookupDefault (pgConfigResources def) config "maxResourcesPerStripe"
  return $ PGConfig db stripes idle resources

pgMake :: Initializer b PG PGConfig -> SnapletInit b PG
pgMake config = makeSnaplet "postgresql-typed" "PostgreSQL-Typed interface" (Just getDataDir) $ do
  c <- config
  liftIO $ PGPool <$> createPool (PG.pgConnect (pgConfigDatabase c)) PG.pgDisconnect
    (pgConfigNumStripes c) (realToFrac $ pgConfigIdleTime c) (pgConfigResources c)

pgInit :: SnapletInit b PG
pgInit = pgMake (liftIO . getPGConfig =<< getSnapletUserConfig)

pgInit' :: PGConfig -> SnapletInit b PG
pgInit' config = pgMake (return config)


pgRunQuery :: (HasPG m, PG.PGQuery q a) => q -> m (Int, Seq a)
pgRunQuery q = liftPG $ \c -> PG.pgRunQuery c q

pgExecute :: (HasPG m, PG.PGQuery q ()) => q -> m Int
pgExecute q = liftPG $ \c -> PG.pgExecute c q

pgExecute1 :: (HasPG m, PG.PGQuery q ()) => q -> m ()
pgExecute1 q = do
  r <- pgExecute q
  when (r /= 1) $ fail $ "pgExecute1: " ++ show r ++ " rows"

pgQuery :: (HasPG m, PG.PGQuery q a) => q -> m [a]
pgQuery q = liftPG $ \c -> PG.pgQuery c q

pgQuery1 :: (HasPG m, PG.PGQuery q a) => q -> m (Maybe a)
pgQuery1 q = do
  r <- pgQuery q
  case r of
    [] -> return $ Nothing
    [x] -> return $ Just x
    _ -> fail "pgQuery1: too many results"

{-# NOINLINE usedTPG #-}
usedTPG :: IORef Bool
usedTPG = unsafePerformIO $ newIORef False
useTPG :: TH.DecsQ
useTPG = do
  d <- TH.runIO $ atomicModifyIORef' usedTPG ((,) True)
  if d
    then return []
    else PG.useTPGDatabase =<< TH.runIO (loadPGDatabase "snaplets/postgresql-typed/devel.cfg")
