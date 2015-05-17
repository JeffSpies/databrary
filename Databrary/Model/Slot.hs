{-# LANGUAGE OverloadedStrings, RecordWildCards, TemplateHaskell, QuasiQuotes #-}
module Databrary.Model.Slot
  ( module Databrary.Model.Slot.Types
  , lookupSlot
  , auditSlotDownload
  , slotJSON
  ) where

import Database.PostgreSQL.Typed (pgSQL)

import Databrary.Ops
import qualified Databrary.JSON as JSON
import Databrary.Service.DB
import Databrary.Model.Id
import Databrary.Model.Identity
import Databrary.Model.Audit
import Databrary.Model.Segment
import Databrary.Model.Container
import Databrary.Model.Slot.Types

useTPG

lookupSlot :: (MonadDB m, MonadHasIdentity c m) => Id Slot -> m (Maybe Slot)
lookupSlot (Id (SlotId c s)) =
  fmap (`Slot` s) <$> lookupContainer c

auditSlotDownload :: MonadAudit c m => Bool -> Slot -> m ()
auditSlotDownload success Slot{ slotContainer = c, slotSegment = seg } = do
  ai <- getAuditIdentity
  dbExecute1' [pgSQL|$INSERT INTO audit.slot (audit_action, audit_user, audit_ip, container, segment) VALUES
    (${if success then AuditActionOpen else AuditActionAttempt}, ${auditWho ai}, ${auditIp ai}, ${containerId c}, ${seg})|]

slotJSON :: Slot -> JSON.Object
slotJSON Slot{..} = containerJSON slotContainer JSON..+?
  ( segmentFull slotSegment ?!> ("segment" JSON..= slotSegment)
  )