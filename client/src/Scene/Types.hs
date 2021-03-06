module Scene.Types where

import Annotate.Prelude

import Reflex.Classes
import Data.Semigroup
import Data.Default

import Annotate.Geometry
import Annotate.Common
import Annotate.Editor

import Input.Events

import Client.Common

data SceneInputs t = SceneInputs
  { mouseDown :: !(Button -> Event t ())
  , mouseUp   :: !(Button -> Event t ())
  , click     :: !(Button -> Event t ())

  , mouseDownOn :: Event t DocPart
  , mouseClickOn :: Event t DocPart

  , mouseDoubleClickOn :: Event t DocPart

  , wheel     :: !(Event t Float)
  , focus     :: !(Event t Bool)

  , keyUp   :: !(Key -> Event t ())
  , keyDown :: !(Key -> Event t ())
  , keyPress :: !(Key -> Event t ())

  , localKeyDown :: !(Key -> Event t ())

  , keysDown    :: !(Event t Key)
  , keysUp      :: !(Event t Key)
  , keysPressed :: !(Event t Key)

  , localKeysDown :: !(Event t Key)

  , keyboard :: !(Dynamic t (Set Key))
  , hover :: !(Dynamic t (Maybe DocPart))

  , mouse    :: !(Dynamic t Position)
  , pageMouse :: !(Dynamic t Position)

  , keyCombo  :: !(Key -> [Key] -> Event t ())

} deriving Generic



data Viewport = Viewport
  { image    :: !Dim
  , window    :: !Dim
  , pan     :: !Position
  , zoom    :: !Float
  } deriving (Generic, Eq, Show)


type Image = (DocName, Dim)
type Controls = (Float, V2 Float)


data Scene t = Scene
  { image    :: !Image
  , neighbours :: !([Image], [Image])
  , input    :: !(SceneInputs t)

  , editor      :: !(Dynamic t Editor)
  , currentEdit :: !(Dynamic t Editor)

  , selection :: !(Dynamic t DocParts)
  , annotations  :: !(Incremental t (PatchMap AnnotationId Annotation))

  , currentClass :: !(Dynamic t ClassId)
  , config       :: !(Dynamic t Config)
  , preferences  :: !(Dynamic t Preferences)

  , shortcut     :: !(EventSelector t Shortcut)
  , viewport     :: !(Dynamic t Viewport)
  , thresholds   :: !(Dynamic t (Float, Float))
  } deriving (Generic)
