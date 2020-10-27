import Foundation
import Stencil

public class FieldGenerator {
  public enum FragmentMode {
    case none
    case getterOnly
    case setterOnly
    case getterAndSetter
    
    var declaration: String {
      switch self {
      case .none: return ""
      case .getterOnly: return "{ get }"
      case .setterOnly: return "{ set }"
      case .getterAndSetter: return "{ get set }"
      }
    }
  }
  
  public enum Accessor {
    case mutable
    case immutable
    
    var declaration: String {
      switch self {
      case .mutable: return "var"
      case .immutable: return "let"
      }
    }
  }
  
  public struct SanitizedField {
    public let name: String
    public let nameVariableDeclaration: String
    public let nameVariableUsage: String
    public let swiftType: String
    public let description: String?
    public let isDeprecated: Bool
    public let fields: [SanitizedField]?
    
    init(field: ASTField) throws {
      self.name = field.responseName
      self.nameVariableDeclaration = field.responseName.apollo.sanitizedVariableDeclaration
      self.nameVariableUsage = field.responseName.apollo.sanitizedVariableUsage

      // TODO: Figure out if the underlying type here is a union or variable type. How? No idea.
      self.swiftType = try field.typeNode.toSwiftType()
            
      self.description = field.description
      self.isDeprecated = field.isDeprecated.apollo.boolValue
      
      self.fields = try field.fields?.map { try SanitizedField(field: $0) }
    }
  }
  
  public enum FieldContextKey: String {
    case field
    case accessor
    case modifier
    case fragmentDeclaration
  }
  
  func run(field: ASTField,
           accessor: Accessor = .immutable,
           fragmentMode: FragmentMode = .none,
           options: ApolloCodegenOptions) throws -> String {
    let sanitized = try SanitizedField(field: field)
    
    let context: [FieldContextKey: Any] = [
      .field: sanitized,
      .accessor: accessor.declaration,
      .modifier: options.modifier.prefixValue,
      .fragmentDeclaration: fragmentMode.declaration
    ]
    
    if fragmentMode == .none {
      return try Environment().renderTemplate(name: self.fieldTemplate,
                                              context: context.apollo.toStringKeyedDict)
    } else {
      return try Environment().renderTemplate(string: self.fragmentFieldTemplate,
                                              context: context.apollo.toStringKeyedDict)
    }
  }
  
  open var fragmentFieldTemplate: String {
##"""
{% if field.description != nil %}/// {{ field.description }}
{% endif %}{{ accessor }} {{ field.nameVariableDeclaration }}: {{ field.swiftType }} {{ fragmentDeclaration }}
"""##
    
  }
  
  open var fieldTemplate: String {
##"""
{% if field.description != nil %}/// {{ field.description }}
{% endif %}{{ modifier }} {{ accessor.declaration }} {{ field.nameVariableDeclaration }}: {{ field.swiftType }}
"""##
  }
}
