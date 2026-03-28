(defsystem "innatescript"
  :description "Innate language interpreter — a scripting language of intention"
  :author "n8k99"
  :license "MIT"
  :version "0.1.0"
  :pathname "src/"
  :components
  ((:file "packages")
   (:file "types"             :depends-on ("packages"))
   (:file "conditions"        :depends-on ("packages"))
   (:module "parser"
    :components
    ((:file "tokenizer"       :depends-on ("../packages"))
     (:file "parser"          :depends-on ("../packages" "tokenizer"))))
   (:module "eval"
    :components
    ((:file "resolver"        :depends-on ("../packages"))
     (:file "evaluator"       :depends-on ("../packages" "resolver"))
     (:file "stub-resolver"   :depends-on ("../packages" "resolver"))))
   (:file "repl"              :depends-on ("packages" "eval/evaluator" "eval/resolver"))
   (:file "innate"            :depends-on ("packages" "types" "conditions"
                                           "parser/tokenizer" "parser/parser"
                                           "eval/resolver" "eval/evaluator"
                                           "eval/stub-resolver" "repl"))))

(defsystem "innatescript/tests"
  :description "Test suite for the Innate interpreter"
  :depends-on ("innatescript")
  :pathname "tests/"
  :components
  ((:file "packages")
   (:file "test-framework" :depends-on ("packages"))
   (:file "smoke-test"     :depends-on ("packages" "test-framework"))))
