{-# language AllowAmbiguousTypes #-}
{-# language DataKinds #-}
{-# language DefaultSignatures #-}
{-# language DisambiguateRecordFields #-}
{-# language FlexibleContexts #-}
{-# language FlexibleInstances #-}
{-# language ScopedTypeVariables #-}
{-# language StandaloneKindSignatures #-}
{-# language TypeApplications #-}
{-# language TypeFamilies #-}
{-# language TypeOperators #-}
{-# language UndecidableInstances #-}
{-# language UndecidableSuperClasses #-}
{-# language ViewPatterns #-}

module Rel8.Table.Ord
  ( OrdTable( ordTable ), (<:), (<=:), (>:), (>=:), least, greatest
  )
where

-- base
import Data.Functor.Const ( Const( Const ), getConst )
import Data.Kind ( Constraint, Type )
import GHC.Generics ( Rep, (:*:), K1, M1, Meta( MetaSel ), D, C, S )
import GHC.TypeLits ( KnownSymbol )
import Prelude hiding ( seq )

-- rel8
import Rel8.Expr ( Expr, Col(..) )
import Rel8.Expr.Bool ( (||.), (&&.), false, true )
import Rel8.Expr.Eq ( (==.) )
import Rel8.Expr.Ord ( (<.), (>.) )
import Rel8.Generic.Record ( Record )
import Rel8.Schema.Context.Label ( hlabeler )
import Rel8.Schema.Dict ( Dict( Dict ) )
import Rel8.Schema.HTable
  ( HTable, HConstrainTable
  , htabulateA, hfield, hdicts
  )
import Rel8.Schema.HTable.Label ( HLabel, hlabel )
import Rel8.Schema.HTable.Product ( HProduct(..) )
import Rel8.Schema.HTable.Type ( HType(..) )
import Rel8.Schema.Kind ( Context )
import Rel8.Schema.Null (Sql)
import Rel8.Schema.Spec.ConstrainDBType ( ConstrainDBType )
import Rel8.Table ( Table, Columns, toColumns, GColumns )
import Rel8.Table.Bool ( bool )
import Rel8.Table.Eq ( EqTable )
import Rel8.Type.Eq ( DBEq )
import Rel8.Type.Ord ( DBOrd )


-- | The class of 'Table's that can be ordered. Ordering on tables is defined
-- by their lexicographic ordering of all columns, so this class means "all
-- columns in a 'Table' have an instance of 'DBOrd'".
type OrdTable :: Type -> Constraint
class EqTable a => OrdTable a where
  ordTable :: Columns a (Dict (ConstrainDBType DBOrd))

  default ordTable ::
    ( GColumns (Rep (Record a)) ~ Columns a
    , GOrdTable (Rep (Record a))
    )
    => Columns a (Dict (ConstrainDBType DBOrd))
  ordTable = gordTable @(Rep (Record a))


type GOrdTable :: (Type -> Type) -> Constraint
class GOrdTable rep where
  gordTable :: GColumns rep (Dict (ConstrainDBType DBOrd))


instance GOrdTable rep => GOrdTable (M1 D c rep) where
  gordTable = gordTable @rep


instance GOrdTable rep => GOrdTable (M1 C c rep) where
  gordTable = gordTable @rep


instance (GOrdTable rep1, GOrdTable rep2) => GOrdTable (rep1 :*: rep2) where
  gordTable = HProduct (gordTable @rep1) (gordTable @rep2)


instance
  ( OrdTable a
  , KnownSymbol label
  , GColumns (M1 S meta k1) ~ HLabel label (Columns a)
  , meta ~ 'MetaSel ('Just label) _su _ss _ds
  , k1 ~ K1 i a
  )
  => GOrdTable (M1 S meta k1)
 where
  gordTable = hlabel hlabeler (ordTable @a)


instance
  ( Table Expr (t (Expr :: Context))
  , f ~ Expr
  , HConstrainTable (Columns (t Expr)) (ConstrainDBType DBEq)
  , HConstrainTable (Columns (t Expr)) (ConstrainDBType DBOrd)
  )
  => OrdTable (t f)
 where
  ordTable = hdicts @(Columns (t f)) @(ConstrainDBType DBOrd)


instance
  ( HTable t
  , f ~ Col Expr
  , HConstrainTable t (ConstrainDBType DBEq)
  , HConstrainTable t (ConstrainDBType DBOrd)
  )
  => OrdTable (t f)
 where
  ordTable = hdicts @(Columns (t f)) @(ConstrainDBType DBOrd)


instance Sql DBOrd a => OrdTable (Expr a) where
  ordTable = HType Dict


instance (OrdTable a, OrdTable b) => OrdTable (a, b)


instance (OrdTable a, OrdTable b, OrdTable c) => OrdTable (a, b, c)


instance (OrdTable a, OrdTable b, OrdTable c, OrdTable d) => OrdTable (a, b, c, d)


instance (OrdTable a, OrdTable b, OrdTable c, OrdTable d, OrdTable e) =>
  OrdTable (a, b, c, d, e)


-- | Test if one 'Table' sorts before another. Corresponds to comparing all
-- columns with '<'.
(<:) :: forall a. OrdTable a => a -> a -> Expr Bool
(toColumns -> as) <: (toColumns -> bs) =
  foldr @[] go false $ getConst $ htabulateA $ \field ->
    case (hfield as field, hfield bs field) of
      (DB a, DB b) -> case hfield (ordTable @a) field of
        Dict -> Const [(a <. b, a ==. b)]
  where
    go (lt, eq) a = lt ||. (eq &&. a)
infix 4 <:


-- | Test if one 'Table' sorts before, or is equal to, another. Corresponds to
-- comparing all columns with '<='.
(<=:) :: forall a. OrdTable a => a -> a -> Expr Bool
(toColumns -> as) <=: (toColumns -> bs) =
  foldr @[] go true $ getConst $ htabulateA $ \field ->
    case (hfield as field, hfield bs field) of
      (DB a, DB b) -> case hfield (ordTable @a) field of
        Dict -> Const [(a <. b, a ==. b)]
  where
    go (lt, eq) a = lt ||. (eq &&. a)
infix 4 <=:


-- | Test if one 'Table' sorts after another. Corresponds to comparing all
-- columns with '>'.
(>:) :: forall a. OrdTable a => a -> a -> Expr Bool
(toColumns -> as) >: (toColumns -> bs) =
  foldr @[] go false $ getConst $ htabulateA $ \field ->
    case (hfield as field, hfield bs field) of
      (DB a, DB b) -> case hfield (ordTable @a) field of
        Dict -> Const [(a >. b, a ==. b)]
  where
    go (gt, eq) a = gt ||. (eq &&. a)
infix 4 >:


-- | Test if one 'Table' sorts after another. Corresponds to comparing all
-- columns with '>='.
(>=:) :: forall a. OrdTable a => a -> a -> Expr Bool
(toColumns -> as) >=: (toColumns -> bs) =
  foldr @[] go true $ getConst $ htabulateA $ \field ->
    case (hfield as field, hfield bs field) of
      (DB a, DB b) -> case hfield (ordTable @a) field of
        Dict -> Const [(a >. b, a ==. b)]
  where
    go (gt, eq) a = gt ||. (eq &&. a)
infix 4 >=:


-- | Given two 'Table's, return the table that sorts before the other.
least :: OrdTable a => a -> a -> a
least a b = bool a b (a <: b)


-- | Given two 'Table's, return the table that sorts after the other.
greatest :: OrdTable a => a -> a -> a
greatest a b = bool a b (a >: b)
