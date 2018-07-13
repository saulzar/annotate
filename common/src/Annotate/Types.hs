module Annotate.Types (
  module Annotate.Types,
  module Annotate.Geometry,
  module Annotate.Colour,

  Generic(..),
) where

import Annotate.Common
import Annotate.Colour

import qualified Data.Map as M

import Data.Generics.Product
import Annotate.Geometry

import Control.Lens (makePrisms)

type AnnotationId = Int
type ClientId = Int
type ClassId = Int

type DocName = Text
type DateTime = UTCTime

data DocCmd = DocEdit Edit | DocUndo | DocRedo
  deriving (Show, Eq, Generic)

data Edit
  = Add [(AnnotationId, Annotation)]
  | Delete [AnnotationId]
  | Transform [AnnotationId] Float Vec
  deriving (Generic, Show, Eq)


data Shape = BoxShape     Box
           | PolygonShape Polygon
           | LineShape    WideLine
   deriving (Generic, Show, Eq)

data ShapeConfig = BoxConfig | PolygonConfig | LineConfig   
  deriving (Generic, Show, Eq)

instance HasBounds Shape where
 getBounds (BoxShape s)     = getBounds s
 getBounds (PolygonShape s) = getBounds s
 getBounds (LineShape s)    = getBounds s
   

data Annotation = Annotation { shape :: Shape, label :: ClassId, predictions :: [(ClassId, Float)] }
    deriving (Generic, Show, Eq)


type AnnotationMap = Map AnnotationId Annotation

data Document = Document
  { undos :: [Edit]
  , redos :: [Edit]
  , name  :: DocName
  , info  :: DocInfo
  , annotations :: AnnotationMap
  } deriving (Generic, Show, Eq)


data ImageCat = New | Train | Test | Discard deriving (Eq, Ord, Enum, Generic, Show)

data DocInfo = DocInfo
  { modified :: Maybe DateTime
  , category :: ImageCat
  , imageSize :: (Int, Int)
  } deriving (Generic, Show, Eq)


data ClassConfig = ClassConfig 
  { name :: Text
  , shape :: ShapeConfig
  , colour :: HexColour
  }
  deriving (Generic, Show, Eq)
  
  
data Config = Config
  { root      :: Text
  , extensions :: [Text]
  , classes    :: Map ClassId ClassConfig
  } deriving (Generic, Show, Eq)

data Collection = Collection
  { config :: Config
  , images :: Map DocName DocInfo
  } deriving (Generic, Show, Eq)


data ErrCode = ErrDecode Text | ErrNotFound DocName | ErrNotRunning | ErrTrainer Text
   deriving (Generic, Show, Eq)


data ServerMsg
  = ServerHello ClientId Config
  | ServerUpdateInfo DocName DocInfo
  | ServerDocument Document
  | ServerOpen (Maybe DocName) ClientId DateTime
  | ServerError ErrCode
  | ServerEnd
      deriving (Generic, Show, Eq)

data ClientMsg
  = ClientOpen DocName
  | ClientNext (Maybe DocName)
  | ClientSubmit Document
  | ClientDiscard DocName
  | ClientDetect DocName

      deriving (Generic, Show, Eq)

instance FromJSON ShapeConfig
instance FromJSON ClassConfig

instance FromJSON Edit
instance FromJSON DocCmd
instance FromJSON ImageCat
instance FromJSON Shape
instance FromJSON Annotation
instance FromJSON Document
instance FromJSON Config
instance FromJSON DocInfo
instance FromJSON Collection
instance FromJSON ServerMsg
instance FromJSON ClientMsg
instance FromJSON ErrCode

instance ToJSON ShapeConfig
instance ToJSON ClassConfig

instance ToJSON Edit
instance ToJSON DocCmd
instance ToJSON ImageCat
instance ToJSON Shape
instance ToJSON Annotation
instance ToJSON Document
instance ToJSON Config
instance ToJSON DocInfo
instance ToJSON Collection
instance ToJSON ServerMsg
instance ToJSON ClientMsg
instance ToJSON ErrCode


defaultConfig :: Config
defaultConfig = Config
  { root = ""
  , extensions = [".png", ".jpg", ".jpeg"]
  , classes    = M.fromList [(0, defaultClass)]
  }
  
  where
    defaultClass = ClassConfig 
      { name    = "default" 
      , colour  = fromMaybe 0xFFFF00 $ fmap fst (uncons defaultColours)
      , shape   = BoxConfig
      }

makePrisms ''ClientMsg
makePrisms ''ServerMsg
makePrisms ''DocCmd
makePrisms ''Shape
makePrisms ''Edit
