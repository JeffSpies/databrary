{-# LANGUAGE DefaultSignatures, GeneralizedNewtypeDeriving, OverloadedStrings #-}
module Databrary.Service.DB
  ( DBConn
  , initDB
  , DBM
  , dbRunQuery
  , dbTryQuery
  , dbExecute
  , dbExecuteSimple
  , dbExecute1
  , dbExecute1'
  , dbQuery
  , dbQuery1
  , dbQuery1'
  , dbTransaction
  , DBTransaction
  , useTPG
  ) where

import Control.Applicative (Applicative, (<$>))
import Control.Exception (onException, tryJust)
import Control.Monad (unless, (<=<))
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Reader (ReaderT(..))
import qualified Data.Configurator as C
import qualified Data.Configurator.Types as C
import Data.IORef (IORef, newIORef, atomicModifyIORef')
import Data.Maybe (fromMaybe, isJust)
import Data.Pool (Pool, withResource, createPool)
import Database.PostgreSQL.Typed.Protocol
import Database.PostgreSQL.Typed.Query
import Database.PostgreSQL.Typed.TH (withTPGConnection, useTPGDatabase)
import qualified Language.Haskell.TH as TH
import Network (PortID(..))
import System.IO.Unsafe (unsafePerformIO)

import Databrary.Has (MonadHas, Has, peek)

getPGDatabase :: C.Config -> IO PGDatabase
getPGDatabase conf = do
  host <- C.lookup conf "host"
  port <- C.lookupDefault (5432 :: Int) conf "port"
  sock <- C.lookupDefault "/tmp/.s.PGSQL.5432" conf "sock"
  user <- C.require conf "user"
  db <- C.lookupDefault user conf "db"
  passwd <- C.lookupDefault "" conf "pass"
  debug <- C.lookupDefault False conf "debug"
  return $ defaultPGDatabase
    { pgDBHost = fromMaybe "localhost" host
    , pgDBPort = if isJust host then PortNumber (fromIntegral port) else UnixSocket sock
    , pgDBName = db
    , pgDBUser = user
    , pgDBPass = passwd
    , pgDBDebug = debug
    }

newtype DBConn = PGPool (Pool PGConnection)

initDB :: C.Config -> IO DBConn
initDB conf = do
  db <- getPGDatabase conf
  PGPool <$> createPool
    (pgConnect db)
    pgDisconnect
    1 60 16

class (Functor m, Applicative m, Monad m) => DBM m where
  liftDB :: (PGConnection -> IO a) -> m a
  default liftDB :: (MonadIO m, MonadHas DBConn c m) => (PGConnection -> IO a) -> m a
  liftDB f = do
    PGPool db <- peek
    liftIO $ withResource db f

instance (Functor m, Applicative m, MonadIO m, Has DBConn c) => DBM (ReaderT c m)

dbRunQuery :: (DBM m, PGQuery q a) => q -> m (Int, [a])
dbRunQuery q = liftDB $ \c -> pgRunQuery c q

dbTryQuery :: (DBM m, PGQuery q a) => (PGError -> Maybe e) -> q -> m (Either e (Int, [a]))
dbTryQuery err q = liftDB $ \c -> tryJust err (pgRunQuery c q)

dbExecute :: (DBM m, PGQuery q ()) => q -> m Int
dbExecute q = liftDB $ \c -> pgExecute c q

dbExecuteSimple :: DBM m => PGSimpleQuery () -> m Int
dbExecuteSimple = dbExecute

dbExecute1 :: (DBM m, PGQuery q ()) => q -> m Bool
dbExecute1 q = do
  r <- dbExecute q
  case r of
    0 -> return False
    1 -> return True
    _ -> fail $ "pgExecute1: " ++ show r ++ " rows"

dbExecute1' :: (DBM m, PGQuery q ()) => q -> m ()
dbExecute1' q = do
  r <- dbExecute1 q
  unless r $ fail $ "pgExecute1': failed"

dbQuery :: (DBM m, PGQuery q a) => q -> m [a]
dbQuery q = liftDB $ \c -> pgQuery c q

dbQuery1 :: (DBM m, PGQuery q a) => q -> m (Maybe a)
dbQuery1 q = do
  r <- dbQuery q
  case r of
    [] -> return $ Nothing
    [x] -> return $ Just x
    _ -> fail "pgQuery1: too many results"

dbQuery1' :: (DBM m, PGQuery q a) => q -> m a
dbQuery1' = maybe (fail "pgQuery1': no results") return <=< dbQuery1

newtype DBTransaction a = DBTransaction { runDBTransaction :: ReaderT PGConnection IO a } deriving (Functor, Applicative, Monad, MonadIO)

instance DBM DBTransaction where
  liftDB = DBTransaction . ReaderT

dbTransaction :: DBM m => DBTransaction a -> m a
dbTransaction f = liftDB $ \c -> do
  pgSimpleQuery c "BEGIN"
  onException (do
    r <- runReaderT (runDBTransaction f) c
    pgSimpleQuery c "COMMIT"
    return r)
    (pgSimpleQuery c "ROLLBACK")

loadTPG :: TH.DecsQ
loadTPG = useTPGDatabase =<< TH.runIO (getPGDatabase . C.subconfig "db" =<< C.load [C.Required "databrary.conf"])

{-# NOINLINE usedTPG #-}
usedTPG :: IORef Bool
usedTPG = unsafePerformIO $ newIORef False
useTPG :: TH.DecsQ
useTPG = do
  d <- TH.runIO $ atomicModifyIORef' usedTPG ((,) True)
  if d
    then return []
    else loadTPG

instance DBM TH.Q where
  liftDB f = do
    _ <- useTPG
    TH.runIO $ withTPGConnection f
