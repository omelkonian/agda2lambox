-- | Re-export things from the Agda library.
module Agda.Lib
  ( module Data.Word
  , module Agda.Syntax.Position
  , module Agda.Syntax.Common
  , module Agda.Syntax.TopLevelModuleName
  , module Agda.Syntax.Abstract.Name
  , module Agda.Syntax.Internal
  , module Agda.Syntax.Literal
  , module Agda.Syntax.Translation.InternalToAbstract
  , module Agda.Compiler.ToTreeless
  , module Agda.Syntax.Treeless
  , module Agda.Compiler.Treeless.Pretty
  , module Agda.Compiler.Treeless.EliminateLiteralPatterns
  -- , module Agda.Compiler.Treeless.Subst
  , module Agda.TypeChecking.Monad
  , module Agda.TypeChecking.Free
  , module Agda.TypeChecking.Datatypes
  , module Agda.TypeChecking.Records
  , module Agda.TypeChecking.Level
  , module Agda.TypeChecking.Substitute
  , module Agda.TypeChecking.Telescope
  , module Agda.TypeChecking.Primitive
  , module Agda.TypeChecking.Reduce
  , module Agda.TypeChecking.CheckInternal
  , module Agda.TypeChecking.CompiledClause
  , module Agda.Main
  , module Agda.Compiler.Common
  , module Agda.Compiler.Backend
  , module Agda.Syntax.Common.Pretty
  , module Agda.TypeChecking.Pretty
  , module Text.Show.Pretty
  , module Agda.Utils.Monad
  , module Agda.Utils.Maybe
  , module Agda.Utils.List
  , module Agda.Utils.Lens
  , module Agda.Utils.Impossible
  ) where

import Data.Word ( Word64 )

-- * common syntax
import Agda.Syntax.Position
  ( Range(..), rStart, posLine )
import Agda.Syntax.Common
  ( Arg, unArg, defaultArg, defaultArgInfo
  , ArgInfo
  , ArgName, bareNameWithDefault
  , Erased(..)
  , LensQuantity(..), hasQuantity0
  , LensHiding(..), visible
  , MetaId(..), NameId(NameId)
  , Ranged(..), Origin(..), getOrigin )
import Agda.Syntax.TopLevelModuleName
  ( TopLevelModuleName, moduleNameToFileName )

-- * abstract syntax
import Agda.Syntax.Abstract.Name
  ( qnameToList0, isNoName )

-- * internal syntax
import Agda.Syntax.Internal
  ( QName, qnameName, qnameModule, qnameFromList
  , Term(..), Type, Type''(El), unEl
  , Level(..)
  , Sort(..), Sort'(..), isSort, getSort
  , Abs(..), unAbs, absName
  , Dom(..), unDom, domName, pDom, defaultDom
  , Elim, Elim'(..), Elims, argsFromElims
  , Telescope, Tele(..), ListTel, telToList, telFromList
  , ConHead(..), ConInfo(..)
  , Clause(..)
  , nameId, dbPatVarIndex, arity
  , Substitution'(..)
  )
import Agda.Syntax.Literal
  ( Literal(..) )
import Agda.Syntax.Translation.InternalToAbstract
  ( NamedClause(..) )

-- * treeless syntax
import Agda.Compiler.ToTreeless ( toTreeless )
import Agda.Syntax.Treeless
  ( TTerm(..), TPrim(..), TAlt(..)
  , CaseInfo(..), CaseType(..)
  , EvaluationStrategy(..), isPrimEq
  , mkTLam, mkTApp, tLamView )
import Agda.Compiler.Treeless.Pretty ()
import Agda.Compiler.Treeless.EliminateLiteralPatterns
  ( eliminateLiteralPatterns )
-- import Agda.Compiler.Treeless.Subst
--   ( freeIn )

-- * typechecking
import Agda.TypeChecking.Monad
  ( TCM, MonadTCM(liftTCM), MonadTCEnv, MonadReduce
  , PureTCM, ReadTCState, HasConstInfo, MonadAddContext
  , TCErr
  , HasBuiltins, BuiltinId, getBuiltinName', litType
  , typeOfConst, getConstInfo, instantiateDef
  , typeOfBV
  , getContext, addContext
  , reportSLn, VerboseLevel
  , Definition(..), Defn(..)
  , pattern Function
  , funProjection, funClauses, funWith, funExtLam, funMutual, funErasure
  , funInline, funCompiled
  , Projection(..), droppedPars
  , pattern Datatype, dataCons, dataPars
  , pattern Constructor
  , pattern Record, recConHead, recPars, recTel
  , pattern Axiom, pattern DataOrRecSig
  , pattern Primitive, pattern PrimitiveSort
  , withCurrentModule, iInsideScope, setScope
  , CompilerPragma(..), getUniqueCompilerPragma )
import Agda.TypeChecking.Free
  ( freeVars, VarCounts(..) )
import Agda.TypeChecking.Datatypes
  ( getConstructorData, getConstructors, getConHead )
import Agda.TypeChecking.Records
  ( isRecord, isRecordConstructor, isRecordType )
import Agda.TypeChecking.Level
  ( isLevelType )
import Agda.TypeChecking.Substitute
  ( TelV(..), Subst(..), DeBruijn(..)
  , raise, raiseFrom, strengthen, piApply )
import Agda.TypeChecking.Telescope
  ( telViewPath, telViewUpTo, telView, typeArity, piApplyM )
import Agda.TypeChecking.Primitive
  ( isBuiltin, primType, Nat(..) )
import Agda.TypeChecking.Reduce
  ( reduce )
import Agda.TypeChecking.CheckInternal
  ( MonadCheckInternal, infer )
import Agda.TypeChecking.CompiledClause
  ( CompiledClauses, CompiledClauses'(..) )

-- * backends
import Agda.Main
  ( runAgda )
import Agda.Compiler.Common
  ( curIF, compileDir )
import Agda.Compiler.Backend
  ( Backend(..), Backend'(..), Backend_boot(..), Backend'_boot(..)
  , Recompile(..), IsMain, nameBindingSite
  , iForeignCode, getForeignCodeStack, ForeignCode(..)
  , Flag )

-- * pretty-printing
import Agda.Syntax.Common.Pretty
  ( Pretty, prettyShow, renderStyle, Style(..), Mode(..) )
import Agda.TypeChecking.Pretty
  ( PrettyTCM(..), MonadPretty, fsep, punctuate, braces, parens, Doc )
import Agda.TypeChecking.Pretty
  hiding (text)
import Text.Show.Pretty
  ( ppShow )

-- * Agda utilities
import Agda.Utils.Monad
  ( ifM, ifNotM, mapMaybeM, partitionM, whenM, concatMapM )
import Agda.Utils.Maybe
  ( ifJustM, boolToMaybe )
import Agda.Utils.List
  ( downFrom, updateLast )
import Agda.Utils.Lens
  ( (^.) )
import Agda.Utils.Impossible
  ( impossible )
