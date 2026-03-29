(defsystem "innatescript"
  :description "Innate language interpreter — a scripting language of intention"
  :author "n8k99"
  :license "MIT"
  :version "0.1.0"
  :pathname "src/"
  :serial nil
  :components
  ((:file "packages")
   (:file "types"             :depends-on ("packages"))
   (:file "conditions"        :depends-on ("packages"))
   (:module "parser"
    :depends-on ("packages")
    :components
    ((:file "tokenizer")
     (:file "parser"          :depends-on ("tokenizer"))))
   (:module "eval"
    :depends-on ("packages")
    :components
    ((:file "resolver")
     (:file "evaluator"       :depends-on ("resolver"))
     (:file "stub-resolver"   :depends-on ("resolver"))))
   (:file "repl"              :depends-on ("packages" "eval"))
   (:file "innate"            :depends-on ("packages" "types" "conditions"
                                           "parser" "eval" "repl"))))

(defsystem "innatescript/tests"
  :description "Test suite for the Innate interpreter"
  :depends-on ("innatescript")
  :pathname "tests/"
  :components
  ((:file "packages")
   (:file "test-framework"  :depends-on ("packages"))
   (:file "smoke-test"      :depends-on ("packages" "test-framework"))
   (:file "test-conditions" :depends-on ("packages" "test-framework"))
   (:file "test-types"      :depends-on ("packages" "test-framework"))
   (:file "test-tokenizer"  :depends-on ("packages" "test-framework"))
   (:file "test-parser"    :depends-on ("packages" "test-framework"))
   (:file "test-resolver"  :depends-on ("packages" "test-framework"))
   (:file "test-stub-resolver" :depends-on ("packages" "test-framework"))
   (:file "test-evaluator"    :depends-on ("packages" "test-framework"))))
