module Annotate.Common (
  module Annotate.Common,
  module Annotate.Geometry,
  module Annotate.Colour,

  Generic(..),
) where

import Annotate.Prelude
import Annotate.Colour

import qualified Data.Map as M
import qualified Data.Set as S

import Data.Generics.Product
import Annotate.Geometry

import Control.Lens (makePrisms)
import Data.Hashable

import qualified Data.Text as Text
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Types as Aeson

--import qualified Data.Flat as Flat
--import Data.Flat (Flat)

import Data.Time.Calendar (Day(..))
import Data.Maybe (fromJust)


import Data.List (splitAt, elemIndex,  dropWhile)
import Data.GADT.Compare.TH

import Annotate.TH


type AnnotationId = Int
type ClientId = Int
type UserId = Int

type ClassId = Int

type DocName = Text
type DateTime = UTCTime

type Epoch = Int
type RunId = Int

type NetworkId = (RunId, Epoch)

data Shape = ShapeBox     Box
           | ShapeCircle  Circle
           | ShapePolygon Polygon
           | ShapeLine    WideLine
     deriving (Generic, Show, Eq)


instance ApproxEq Shape where
  (~=) (ShapeBox b) (ShapeBox b') = b ~= b'
  (~=) (ShapeCircle b) (ShapeCircle b') = b ~= b'
  (~=) (ShapePolygon b) (ShapePolygon b') = b ~= b'
  (~=) (ShapeLine b) (ShapeLine b') = b ~= b'
  (~=) _ _ = False


data ShapeKey a where
  BoxKey      :: ShapeKey Box
  CircleKey   :: ShapeKey Circle
  PolygonKey  :: ShapeKey Polygon
  LineKey     :: ShapeKey WideLine

deriving instance Eq a => Eq (ShapeKey a)

shapeKey :: Shape -> DSum ShapeKey Identity
shapeKey (ShapeBox b)     = BoxKey      :=> Identity b
shapeKey (ShapeCircle c)  = CircleKey   :=> Identity c
shapeKey (ShapePolygon p) = PolygonKey  :=> Identity p
shapeKey (ShapeLine l)    = LineKey    :=> Identity l


deriveGEq ''ShapeKey
deriveGCompare ''ShapeKey

data ShapeConfig = ConfigCircle | ConfigBox | ConfigPolygon | ConfigLine
  deriving (Generic, Show, Eq, Ord)
 

instance HasBounds Shape where
 getBounds (ShapeCircle s)  = getBounds s
 getBounds (ShapeBox s)     = getBounds s
 getBounds (ShapePolygon s) = getBounds s
 getBounds (ShapeLine s)    = getBounds s

data Detection = Detection
  { label      :: ClassId
  , shape      :: Shape
  , confidence :: Float
  , match      :: Maybe AnnotationId
  } deriving (Generic, Show, Eq)

data DetectionTag 
  = Detected
  | Review
  | Missed
  | Deleted 
  | Confirmed Bool
    deriving (Generic, Show, Eq)


data Annotation = Annotation
  { shape :: Shape
  , label :: ClassId
  , detection :: Maybe (DetectionTag, Detection)
  } deriving (Generic, Show, Eq)

data BasicAnnotation = BasicAnnotation 
  { shape :: Shape
  , label :: ClassId
  } deriving (Generic, Show, Eq)

instance ApproxEq Annotation where
  (~=) (Annotation s l d) (Annotation s' l' d') = s ~= s' && l == l' && d == d'

instance ApproxEq BasicAnnotation where
  (~=) (BasicAnnotation s l) (BasicAnnotation s' l') = s ~= s' && l == l'
  

type AnnotationMap = Map AnnotationId Annotation
type BasicAnnotationMap = Map AnnotationId BasicAnnotation

type DocParts = Map AnnotationId (Set Int)
type Rigid = (Float, Vec)

data Edit
  = EditSetClass ClassId (Set AnnotationId)
  | EditDeleteParts DocParts
  | EditTransformParts Rigid DocParts
  | EditClearAll
  | EditAdd [BasicAnnotation]
  | EditConfirmDetection (Map AnnotationId Bool)
  deriving (Generic, Show, Eq)


data AnnotationPatch
  = Add Annotation
  | Delete
  | Transform Rigid (Set Int)
  | SetTag DetectionTag
  | SetClass ClassId
  deriving (Generic, Show, Eq)


data DocumentPatch
    = PatchAnns (Map AnnotationId AnnotationPatch)
    -- | PatchArea (Maybe Box)
  deriving (Eq, Show, Generic)


data OpenType = OpenNew Detections | OpenReview Detections | OpenDisconnected 
  deriving (Show,  Generic)


data Session = Session 
  { initial    :: Map AnnotationId BasicAnnotation
  , threshold  :: Float
  , open       :: OpenType
  , time       :: UTCTime
  , history    :: [HistoryPair]
  } deriving (Show, Generic)

type HistoryPair = (UTCTime, HistoryEntry)  

data OpenSession = OpenSession 
  { initial    :: BasicAnnotationMap
  , threshold  :: Float
  , openType :: OpenType
  }   deriving (Show,  Generic)


data HistoryEntry 
  = HistoryEdit Edit 
  | HistoryUndo 
  | HistoryRedo 
  | HistoryThreshold Float
  | HistoryOpen OpenSession
  | HistoryClose 
  deriving (Show,  Generic)

data EditCmd = DocEdit Edit | DocUndo | DocRedo
  deriving (Show, Eq, Generic)


newtype NaturalKey = NaturalKey [Either Int Text]
  deriving (Ord, Eq, Generic, Show)

type Count = (Float, Int)

data Margins a = Margins
  { lower   :: a
  , middle  :: a
  , upper   :: a
  } deriving (Generic, Functor)  

deriving instance Show a => Show (Margins a)
deriving instance Eq a => Eq (Margins a)

data DetectionStats = DetectionStats 
  { score       ::  Float
  , classScore  ::  Map ClassId Float
  , counts      ::  Maybe (Margins Int)
  , classCounts ::  Maybe (Map ClassId (Margins Count))
  , frameVariation :: Maybe Float
  } deriving (Generic, Eq, Show)  


data Detections = Detections 
  { instances :: [Detection]
  , networkId :: NetworkId
  , stats     :: DetectionStats
  } deriving (Show,  Generic)

data SubmitType
    = SubmitNew 
    | SubmitDiscard 
    | SubmitConfirm (Maybe ImageCat)
    | SubmitAutoSave
  deriving (Show,  Generic)

  
data Submission = Submission 
  { name        :: DocName
  , annotations :: BasicAnnotationMap
  , session     :: Session
  , method      :: SubmitType
  } deriving (Generic, Show)

data TrainSummary = TrainSummary 
  { loss  :: Float
  } deriving (Show, Eq, Generic)  

data Document = Document
  { name  :: DocName
  , info  :: DocInfo

  , annotations    :: BasicAnnotationMap
  , sessions       :: [Session]

  , detections     :: Maybe Detections
  , training       :: [TrainSummary]
  } deriving (Generic, Show)


data ImageCat = CatNew | CatTrain | CatValidate | CatDiscard | CatTest
  deriving (Eq, Ord, Enum, Generic)

instance Show ImageCat where
  show CatNew = "new"
  show CatValidate = "validate"
  show CatTrain = "train"
  show CatDiscard = "discard"
  show CatTest = "test"


newtype Hash32 = Hash32 { unHash :: Word32 }
  deriving (Eq, Ord, Enum, Generic, Show)


data TrainStats = TrainStats 
  { lossMean       :: Float
  , lossRunning    :: Float
  } deriving (Generic, Eq, Show)


data ImageInfo = ImageInfo 
  { size       :: Dim
  , creation   :: Maybe UTCTime
  } deriving (Generic, Eq, Show)

data DocInfo = DocInfo
  { hashedName :: Hash32
  , naturalKey :: NaturalKey
  , modified    :: Maybe DateTime
  , numAnnotations :: Int
  , category    :: ImageCat

  , detections :: Maybe DetectionStats
  , training   :: TrainStats
  , reviews    :: Int

  , image      :: ImageInfo
  } deriving (Generic, Eq, Show)


data ClassConfig = ClassConfig
  { name :: Text
  , shape :: ShapeConfig
  , colour :: HexColour
  , weighting :: Float
  , countWeight :: Int
  } deriving (Generic, Show, Eq)


data Config = Config
  { root      :: Text
  , extensions :: [Text]
  , classes     :: Map ClassId ClassConfig
  } deriving (Generic, Show, Eq)


data SortKey 
  = SortCategory
  | SortAnnotations 
  | SortName 
  | SortModified 
  | SortRandom 
  | SortDetections
  | SortLossMean
  | SortLossRunning
  | SortFrameVariation
  | SortCreation
  | SortCounts
  | SortCountVariation
  deriving (Eq, Show, Generic)


data ImageSelection 
  = SelSequential
  | SelRandom
  | SelDetections
  | SelLoss
  | SelFrameVariation 
  | SelCountVariation
  deriving (Eq, Show, Generic)



data FilterOption 
  = FilterAll 
  | FilterCat ImageCat 
  | FilterEdited 
  | FilterReviewed 
  | FilterForReview
  deriving (Eq, Generic)

instance Show FilterOption where
  show FilterAll        = "all"
  show (FilterCat cat)  = show cat
  show FilterEdited     = "edited"
  show FilterReviewed     = "reviewed"
  show FilterForReview     = "for review"


data SortOptions = SortOptions 
  { sorting  :: (SortKey, Bool)
  , selection :: ImageSelection
  , revSelection :: Bool

  , filtering :: (FilterOption, Bool)
  , search    :: Text
  , restrictClass :: Maybe ClassId
  } deriving (Show, Generic, Eq)

  
data AssignmentMethod
    = AssignCat ImageCat
    | AssignAuto
  deriving (Show, Generic, Eq)

data DisplayPreferences = DisplayPreferences 
  { controlSize       :: Float
  , brushSize         :: Float
  , instanceColours   :: Bool
  , showConfidence    :: Bool
  , opacity           :: Float
  , border            :: Float
  , hiddenClasses     :: Set Int
  , gamma             :: Float
  , brightness        :: Float
  , contrast          :: Float
  , fontSize          :: Int
  } deriving (Generic, Show, Eq)

data Preferences = Preferences
  { display      :: DisplayPreferences
  , detection    :: DetectionParams
  , thresholds    :: (Float, Float)
  , sortOptions :: SortOptions
  , autoDetect  :: Bool
  , reviewing   :: Bool
  , assignMethod   :: AssignmentMethod
  , trainRatio  :: Int
  } deriving (Generic, Show, Eq)

  

data DetectionParams = DetectionParams
  {   nms            :: Float
  ,   threshold      :: Float
  ,   detections     :: Int
  } deriving (Generic, Show, Eq)


data Collection = Collection
  { images :: Map DocName DocInfo
  } deriving (Generic, Show)


data ErrCode
  = ErrDecode Text
  | ErrNotFound NavId DocName
  | ErrNotRunning
  | ErrTrainer Text
  | ErrEnd NavId

  | ErrSubmit Text

    deriving (Generic, Show, Eq)

type NavId = Int

data ServerMsg
  = ServerHello ClientId Preferences Config TrainerStatus
  | ServerConfig Config
  | ServerCollection Collection
  | ServerUpdateInfo DocName DocInfo
  | ServerUpdateTraining (Map DocName TrainStats)
  | ServerUpdateDetections (Map DocName DetectionStats)

  | ServerDocument NavId Document
  | ServerOpen (Maybe DocName) ClientId DateTime
  | ServerError ErrCode
  | ServerDetection DocName Detections
  | ServerStatus TrainerStatus
      deriving (Generic, Show)

 
data Progress = Progress { activity :: TrainerActivity, progress :: (Int, Int) }
  deriving (Generic, Show, Eq)


data TrainerActivity
  = ActivityTrain { epoch :: Epoch }
  | ActivityValidate  { epoch :: Epoch }
  | ActivityTest  { epoch :: Epoch }
  | ActivityReview
  | ActivityDetect
  deriving (Generic,  Eq)


instance Show TrainerActivity where
  show (ActivityTrain epoch) = "Train " <> show epoch
  show (ActivityTest epoch) = "Test " <> show epoch
  show (ActivityValidate epoch) = "Validate " <> show epoch

  show (ActivityReview) = "Review"
  show (ActivityDetect) = "Detect"

data TrainerStatus 
  = StatusDisconnected
  | StatusPaused
  | StatusTraining Progress
  deriving (Generic, Show, Eq)


data StatusKey a where
  DisconnectedKey :: StatusKey ()
  PausedKey       :: StatusKey ()
  TrainingKey    :: StatusKey Progress
    

trainerKey :: TrainerStatus -> DSum StatusKey Identity
trainerKey StatusDisconnected = DisconnectedKey :=> Identity ()
trainerKey StatusPaused       = PausedKey   :=> Identity ()
trainerKey (StatusTraining p) = TrainingKey :=> Identity p

deriveGEq ''StatusKey
deriveGCompare ''StatusKey

data UserCommand 
  = UserPause
  | UserResume
  | UserReview
  | UserDetect
  deriving (Generic, Show, Eq)


data Navigation
  = NavNext
  | NavTo DocName
  | NavForward
  | NavBackward
    deriving (Generic, Show, Eq)

data ConfigUpdate
  = ConfigClass ClassId (Maybe ClassConfig)
    deriving (Generic, Show, Eq)

data ClientMsg 
  = ClientNav NavId Navigation
  | ClientSubmit Submission
  | ClientDetect DocName (BasicAnnotationMap)
  | ClientConfig ConfigUpdate
  | ClientPreferences Preferences
  | ClientCollection
  | ClientCommand UserCommand
      deriving (Generic, Show)




instance Default NaturalKey where
  def = NaturalKey []

instance Default TrainStats where
  def = TrainStats 0 0 

instance Default Text where
  def = ""

instance Default DocInfo where
  def  = DocInfo
    { naturalKey = def
    , hashedName = Hash32 0
    , modified = Nothing
    , category = CatNew
    , numAnnotations = 0
    , detections = def
    , training = def
    , reviews = 0
    , image = ImageInfo (0, 0) Nothing
    }

instance Default Config where
  def = Config
    { root = ""
    , extensions = [".png", ".jpg", ".jpeg"]
    , classes    = M.fromList [(0, newClass 0)]
    }

instance Default DisplayPreferences where
  def = DisplayPreferences
    { controlSize = 10
    , brushSize = 40
    , instanceColours = False
    , opacity = 0.4
    , border = 1
    , hiddenClasses = mempty
    , gamma = 1.0
    , brightness = 0.0
    , contrast = 1.0
    , showConfidence = True
    , fontSize = 12
    }

instance Default Preferences where
  def = Preferences
    { display = def
    , detection = def
    , thresholds = (0.5, 0.2)
    , sortOptions = def
    , autoDetect = True
    , trainRatio = 5
    , assignMethod = AssignAuto
    , reviewing = False
    }

instance Default SortOptions where
  def = SortOptions 
    { sorting = (SortName, False)
    , selection = SelSequential 
    , revSelection = False
    , filtering = (FilterAll, False)
    , search = ""
    , restrictClass = Nothing
    }

instance Default DetectionParams where
  def = DetectionParams
    { nms = 0.5
    , threshold = 0.05
    , detections = 500
    }

instance Default DetectionStats where
  def = DetectionStats 
    { score      = 0
    , classScore = mempty
    , counts = Nothing
    , classCounts = Nothing
    , frameVariation = Nothing
    }

newClass :: ClassId -> ClassConfig
newClass k = ClassConfig
  { name    = "unnamed-" <> fromString (show k)
  , colour  = fromMaybe 0xFFFF00 $ preview (ix k) defaultColours
  , shape   = ConfigBox
  , weighting = 0.25
  , countWeight = 1
  }

fromBasic :: BasicAnnotation -> Annotation
fromBasic BasicAnnotation{..} = Annotation{..} where
  detection = Nothing

toBasic :: Annotation -> BasicAnnotation
toBasic Annotation{shape, label} = BasicAnnotation{shape, label}  



getConfidence :: Annotation -> Float
getConfidence Annotation{detection} = case detection of 
  Just (Detected, d)  -> d ^. #confidence
  Just (Deleted, _) -> 0.0
  _                 -> 1.0

xor :: Bool -> Bool -> Bool
xor True False = True
xor False True = True
xor _ _        = False


maxKey :: Ord k => Map k a -> Maybe k
maxKey = fmap fst . maxMap

minKey :: Ord k => Map k a -> Maybe k
minKey = fmap fst . minMap


maxElem :: Ord k => Map k a -> Maybe a
maxElem = fmap snd . maxMap

minElem :: Ord k => Map k a -> Maybe a
minElem = fmap snd . minMap

maxMap :: Ord k => Map k a -> Maybe (k, a)
maxMap m | M.null m = Nothing
         | otherwise = Just $ M.findMax m

minMap :: Ord k => Map k a -> Maybe (k, a)
minMap m | M.null m = Nothing
        | otherwise = Just $ M.findMin m


setToMap :: Ord k =>  a ->  Set k -> Map k a
setToMap a = M.fromDistinctAscList . fmap (, a) . S.toAscList


setToMap' :: Ord k => Set k -> Map k ()
setToMap' = setToMap ()

data HashedKey k = HashedKey { unKey :: k, hashedKey :: Word32 }
  deriving Show

hashKey :: (Hashable k) => k -> HashedKey k
hashKey k = HashedKey k (fromIntegral $ hash k)

instance (Hashable a, Eq a) => Eq (HashedKey a) where
  (==) k k' = hashedKey k == hashedKey k' && unKey k == unKey k'

instance (Hashable a, Ord a) => Ord (HashedKey a) where
  compare k k' = case compare (hashedKey k) (hashedKey k') of
    GT -> GT
    LT -> LT
    EQ -> compare (unKey k) (unKey k')

hashKeys :: (Ord k, Hashable k) => Map k a -> Map (HashedKey k) a
hashKeys = M.mapKeys hashKey


emptyCollection :: Collection
emptyCollection = Collection mempty



makePrisms ''Navigation
makePrisms ''HistoryEntry

makePrisms ''ClientMsg
makePrisms ''ServerMsg
makePrisms ''Shape

makePrisms ''DetectionTag
makePrisms ''DocumentPatch
makePrisms ''AnnotationPatch



dropCamel :: String -> String
dropCamel name = case f name of 
  ""     -> error ("empty JSON constructor after prefix removed: " <> name)
  result -> result
  where
    f = drop 1 . dropWhile (/= '_') . camel 

camel :: String -> String 
camel = Aeson.camelTo2 '_'

options :: Aeson.Options
options = Aeson.defaultOptions 
  { Aeson.constructorTagModifier = dropCamel
  , Aeson.fieldLabelModifier = Aeson.camelTo2 '_' 
  }

instance FromJSON Hash32 where
  parseJSON (Aeson.String v) = return $ Hash32 $ read (Text.unpack v)
  parseJSON _          = fail "expected string value"

instance ToJSON Hash32 where
  toJSON (Hash32 v) = Aeson.String (Text.pack (show v))

instance ToJSON NaturalKey where
  toJSON (NaturalKey xs) = toJSON (f <$> xs) where 
    f (Left i)  = toJSON i
    f (Right s) = toJSON s

instance FromJSON NaturalKey where
  parseJSON (Aeson.Array xs) = do 
    values <- sequence (numOrInt <$> xs)
    return (NaturalKey (toList values))
      where numOrInt v = Left <$> parseJSON v <|> Right <$> parseJSON v

  parseJSON _ = fail "expected array value"


{-
instance Flat Hash32
instance Flat NaturalKey  

instance Flat DiffTime where
  encode = Flat.encode . diffTimeToPicoseconds
  decode = picosecondsToDiffTime <$> Flat.decode

  size dt = Flat.size (diffTimeToPicoseconds dt)

instance Flat UTCTime where
  encode (UTCTime (ModifiedJulianDay d) dt) = Flat.encode (d, dt)
  decode = do 
    (d, dt) <- Flat.decode 
    return (UTCTime (ModifiedJulianDay d) dt)

  size (UTCTime (ModifiedJulianDay d) dt) bits = Flat.size (d, dt) bits

instance Flat a => Flat (Margins a)

instance Flat a => Flat (Set a) where
  encode = Flat.encode . S.toAscList
  decode = S.fromDistinctAscList <$> Flat.decode
  size  s = Flat.size (S.toAscList s)


instance Flat a => Flat (NonEmpty a) where
  encode = Flat.encode . toList
  decode = fromJust . nonEmpty <$> Flat.decode
  size  s = Flat.size (toList s)  

instance Flat a => Flat (V2 a)
-}

instance FromJSON a => FromJSON (V2 a)
instance ToJSON a => ToJSON (V2 a)


makeInstances 
  [ ''ShapeConfig
  , ''ClassConfig
  , ''DetectionParams
  , ''AssignmentMethod
  , ''Preferences
  , ''DisplayPreferences
  , ''Shape 
  , ''Annotation     
  , ''BasicAnnotation
  , ''DetectionTag       
  , ''Detection  
  , ''Detections  


  , ''AnnotationPatch
  , ''HistoryEntry   
  , ''OpenSession   
  , ''Session   
  , ''OpenType   

  , ''Edit   
  , ''EditCmd

  , ''Navigation   
  , ''ConfigUpdate 

  , ''Document    

  , ''SubmitType    
  , ''Submission    

  , ''Config      

  , ''DetectionStats     

  , ''DocInfo     
  , ''ImageInfo     

  , ''TrainStats     
  , ''Collection  
  , ''ServerMsg   
  , ''ClientMsg   
  , ''ErrCode     

  , ''Progress     
  , ''TrainerStatus


  , ''SortKey      
  , ''FilterOption 
  , ''SortOptions  
  , ''ImageSelection  

  , ''ImageCat


  , ''TrainerActivity
  , ''UserCommand
  , ''TrainSummary

  , ''Box
  , ''Circle
  , ''Polygon
  , ''WideLine
  , ''Segment
  
  , ''Extents
  ]


instance FromJSON a => FromJSON (Margins a) where parseJSON = Aeson.genericParseJSON options
instance ToJSON a => ToJSON (Margins a)     where toJSON    = Aeson.genericToJSON options
