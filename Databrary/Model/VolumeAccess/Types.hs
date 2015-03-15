{-# LANGUAGE TemplateHaskell #-}
module Databrary.Model.VolumeAccess.Types
  ( VolumeAccess(..)
  , MonadHasVolumeAccess
  ) where

import qualified Language.Haskell.TH as TH

import Databrary.Has (makeHasFor)
import Databrary.Model.Id.Types
import Databrary.Model.Permission.Types
import Databrary.Model.Volume.Types
import Databrary.Model.Party.Types

data VolumeAccess = VolumeAccess
  { volumeAccessIndividual, volumeAccessChildren :: Permission
  , volumeAccessParty :: Party
  , volumeAccessVolume :: Volume
  }

makeHasFor ''VolumeAccess
  [ ('volumeAccessVolume, [TH.ConT ''Id `TH.AppT` TH.ConT ''Volume])
  , ('volumeAccessParty, [TH.ConT ''Id `TH.AppT` TH.ConT ''Party])
  ]
