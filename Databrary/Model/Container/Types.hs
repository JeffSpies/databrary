{-# LANGUAGE OverloadedStrings, TemplateHaskell, TypeFamilies #-}
module Databrary.Model.Container.Types
  ( Container(..)
  , MonadHasContainer
  ) where

import qualified Data.Text as T

import Control.Has (makeHasRec)
import Databrary.Model.Time
import Databrary.Model.Kind
import Databrary.Model.Consent.Types
import Databrary.Model.Id.Types
import Databrary.Model.Volume.Types

type instance IdType Container = Int32

data Container = Container
  { containerId :: Id Container
  , containerTop :: Bool
  , containerName :: Maybe T.Text
  , containerDate :: Maybe Date
  , containerConsent :: Maybe Consent
  , containerVolume :: Volume
  }

instance Kinded Container where
  kindOf _ = "container"

makeHasRec ''Container ['containerId, 'containerConsent, 'containerVolume]
