module Databrary.Controller.Volume where

import Databrary.Model.Id.Types
import Databrary.Model.Volume.Types
import Databrary.Action

viewVolume :: AppRoute (API, Id Volume)
viewVolumeForm :: AppRoute (Id Volume)
postVolume :: AppRoute (API, Id Volume)
createVolume :: AppRoute API
viewVolumeLinks :: AppRoute (Id Volume)
postVolumeLinks :: AppRoute (API, Id Volume)
queryVolumes :: AppRoute API