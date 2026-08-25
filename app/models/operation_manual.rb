# Static content for the "Acerca de" page (StaticPagesController#about): the
# per-role operation manual, the Colombian regulatory sources the operation is
# built on, and the feature inventory (shipped vs. pending).
#
# Deliberately in Spanish and not run through i18n: the audience is the Colombian
# operation and every regulatory source it cites is Spanish-language, so there is
# no en/fr/pt copy to fall back to. The navbar label itself IS localized.
#
# The permission matrix here is HARDCODED on purpose (a readable manual, not a
# live dump). Its source of truth is RolesAndPermissionsSeeder::MATRIX — the
# defaults an admin sees before customizing anything in the role manager.
# spec/models/operation_manual_spec.rb fails if the two ever drift apart.
module OperationManual
  # permissions: { "Resource" => [can_show, can_edit, can_delete] }
  RoleGuide = Struct.new(:name, :display_name, :summary, :responsibilities, :permissions, keyword_init: true) do
    # Unrestricted across the whole catalog (admin) — the page says so in a line
    # instead of rendering twenty identical rows of check marks.
    def full_access?
      permissions.keys.sort == PermissionCatalog::RESOURCES.sort &&
        permissions.values.all? { |flags| flags.all? }
    end
  end

  # Spanish labels for the catalog resources. Hardcoded rather than read from
  # `model_name.human` so the page stays entirely in Spanish even when the user
  # has the interface set to another locale.
  RESOURCE_LABELS = {
    "Admin" => "Administradores",
    "Article" => "Artículos",
    "Campaign" => "Campañas",
    "CampaignDocument" => "Documentos de campaña",
    "Category" => "Categorías de estudio",
    "City" => "Ciudades",
    "Contact" => "Contactos",
    "CriteriaProfile" => "Perfiles de criterios",
    "CriteriaVariable" => "Variables de criterios",
    "Medication" => "Medicamentos",
    "Patient" => "Pacientes",
    "PlatformStaff" => "Personal de plataforma",
    "Result" => "Resultados",
    "Sponsor" => "Patrocinadores",
    "SponsorRep" => "Representantes de patrocinador",
    "Study" => "Estudios",
    "TrialCenterBranch" => "Sedes",
    "TrialCenterBranchRep" => "Representantes de sede",
    "TrialCenterFacility" => "Centros de ensayos clínicos",
    "TrialCity" => "Ciudades de ensayo",
    "User" => "Usuarios"
  }.freeze

  def self.resource_label(resource)
    RESOURCE_LABELS.fetch(resource, resource)
  end

  # `url` nil => no verified public URL; the page shows the title only.
  Document = Struct.new(:title, :issuer, :url, :note, keyword_init: true)

  # status: :done | :partial | :pending | :blocked
  Feature = Struct.new(:name, :status, :detail, keyword_init: true)

  # How a permission flag maps onto controller actions (see ApplicationPolicy).
  ACTION_LEGEND = {
    can_show: "Ver — listar (index) y consultar el detalle (show).",
    can_edit: "Editar — crear (new/create) y modificar (edit/update).",
    can_delete: "Eliminar — borrar el registro (destroy)."
  }.freeze

  ADMIN_PERMISSIONS = PermissionCatalog::RESOURCES.index_with { [ true, true, true ] }.freeze

  ROLES = [
    RoleGuide.new(
      name: "admin",
      display_name: "Administrador",
      summary: "Control total de la plataforma. Es el único rol que administra la matriz de roles y permisos, y el único que puede eliminar registros de forma generalizada.",
      responsibilities: [
        "Gestionar usuarios de todos los tipos (administradores, personal de plataforma, representantes y pacientes).",
        "Crear, editar y eliminar cualquier recurso del catálogo.",
        "Ajustar los permisos de cada rol desde el administrador de roles (Usuarios → Gestionar roles).",
        "Consultar el registro de auditoría (change control) de cualquier registro versionado."
      ],
      permissions: ADMIN_PERMISSIONS
    ),
    RoleGuide.new(
      name: "platform_staff",
      display_name: "Personal de Plataforma",
      summary: "Opera el módulo de campañas: construye y mantiene el material con el que se promocionan los estudios. No tiene acceso a datos de pacientes.",
      responsibilities: [
        "Crear campañas asociadas a un estudio y redactar su título, descripción y llamado a la acción.",
        "Cargar y eliminar documentos y piezas gráficas de cada campaña.",
        "Mover la campaña entre borrador, lista y archivada.",
        "Registrar las credenciales de los canales sociales (se guardan cifradas y fuera del registro de auditoría).",
        "Consultar los estudios que promociona, sin poder modificarlos."
      ],
      permissions: {
        "Campaign" => [ true, true, true ],
        "CampaignDocument" => [ true, true, true ],
        "Study" => [ true, false, false ],
        "Article" => [ true, false, false ],
        "Medication" => [ true, false, false ]
      }
    ),
    RoleGuide.new(
      name: "sponsor_rep",
      display_name: "Representante de Patrocinador",
      summary: "Representa a la entidad que financia el estudio. Gestiona el estudio y su contenido científico, pero no accede a datos clínicos identificables de pacientes.",
      responsibilities: [
        "Crear y editar los estudios de su patrocinador, incluyendo fase, estado y ciudades.",
        "Publicar artículos y cargar los resultados (primarios y secundarios) del estudio.",
        "Ver y editar las campañas de promoción de sus estudios (sin poder eliminarlas).",
        "Consultar el patrocinador, los medicamentos y el directorio de usuarios."
      ],
      permissions: {
        "Study" => [ true, true, false ],
        "Article" => [ true, true, false ],
        "Result" => [ true, true, false ],
        "Sponsor" => [ true, false, false ],
        "SponsorRep" => [ true, false, false ],
        "Medication" => [ true, false, false ],
        "User" => [ true, false, false ],
        "Campaign" => [ true, true, false ],
        "CampaignDocument" => [ true, true, false ]
      }
    ),
    RoleGuide.new(
      name: "trial_center_branch_rep",
      display_name: "Representante de Centro",
      summary: "Personal del centro de investigación. Es el único rol operativo que trabaja con datos clínicos de pacientes, y por eso el que más obligaciones normativas concentra.",
      responsibilities: [
        "Registrar y actualizar pacientes, incluyendo su descripción de enfermedad y notas clínicas.",
        "Capturar los valores de las variables del paciente y ejecutar la evaluación de elegibilidad contra el perfil de criterios del estudio.",
        "Mover al paciente por su ciclo de vida: interesado → candidato → participante (y de vuelta cuando corresponda).",
        "Construir y mantener perfiles de criterios y sus variables de inclusión/exclusión.",
        "Cargar resultados y gestionar los contactos del estudio.",
        "Consultar estudios, centros, sedes, ciudades, artículos y medicamentos, sin poder modificarlos."
      ],
      permissions: {
        "Patient" => [ true, true, false ],
        "Contact" => [ true, true, false ],
        "CriteriaProfile" => [ true, true, false ],
        "CriteriaVariable" => [ true, true, false ],
        "Result" => [ true, true, false ],
        "TrialCenterBranchRep" => [ true, true, false ],
        "Study" => [ true, false, false ],
        "TrialCenterBranch" => [ true, false, false ],
        "TrialCenterFacility" => [ true, false, false ],
        "TrialCity" => [ true, false, false ],
        "City" => [ true, false, false ],
        "Article" => [ true, false, false ],
        "Medication" => [ true, false, false ],
        "User" => [ true, false, false ],
        "Campaign" => [ true, false, false ],
        "CampaignDocument" => [ true, false, false ]
      }
    ),
    RoleGuide.new(
      name: "patient",
      display_name: "Paciente",
      summary: "Participante o aspirante a participar en un estudio. Su registro nace siempre desde un estudio concreto: no existe un alta genérica en la plataforma.",
      responsibilities: [
        "Registrarse a partir del estudio en el que desea participar.",
        "Otorgar de forma expresa la autorización de tratamiento de datos sensibles de salud (Ley 1581 de 2012) antes de que se recoja cualquier dato clínico.",
        "Otorgar, cuando el patrocinador del estudio es internacional, la autorización adicional de transferencia internacional (Art. 26).",
        "Consultar sus propios datos y el material informativo de los estudios."
      ],
      permissions: {
        "Study" => [ true, false, false ],
        "Article" => [ true, false, false ],
        "Medication" => [ true, false, false ],
        "Campaign" => [ true, false, false ],
        "CampaignDocument" => [ true, false, false ]
      }
    )
  ].freeze

  # Primary regulatory sources. Local copies of each live in docs/sources/ (see
  # its README) because government links are known to move; the URLs below are
  # the original, citable sources.
  DOCUMENTS = [
    Document.new(
      title: "Ley 1581 de 2012 — Régimen general de protección de datos personales (Habeas Data)",
      issuer: "Congreso de la República",
      url: "https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=49981",
      note: "Base de todo el tratamiento de datos de pacientes: los datos de salud son datos sensibles (Art. 5), su tratamiento exige autorización previa, expresa e informada (Art. 6 y 9), y las transferencias internacionales se rigen por el Art. 26. La autoridad de vigilancia es la SIC."
    ),
    Document.new(
      title: "Decreto 1377 de 2013 — Decreto reglamentario de la Ley 1581",
      issuer: "Presidencia de la República, MinComercio y MinTIC",
      url: "https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=53646",
      note: "Distingue transmisión (a un encargado que trata por cuenta del responsable, Art. 25 — no requiere consentimiento si hay contrato) de transferencia (a otro responsable, Art. 26). Es la razón por la que alojar la plataforma fuera del país es una transmisión cubierta por un contrato, y no un consentimiento por paciente."
    ),
    Document.new(
      title: "Resolución 2378 de 2008 y su Anexo Técnico — Buenas Prácticas Clínicas",
      issuer: "Ministerio de la Protección Social (INVIMA certifica y audita)",
      url: "https://mesagil.invima.gov.co/biblioteca/resolucion_20no_202378_20de_202008_1pdf",
      note: "Norma central para ensayos clínicos en Colombia. Exige que el consentimiento informado esté firmado y fechado por el participante, dos testigos y el médico investigador, y que se vuelva a firmar cada vez que el formato se modifique. Su Tabla 7 exige codificar la identidad del participante frente a los datos de investigación."
    ),
    Document.new(
      title: "Resolución 1995 de 1999 — Manejo de la historia clínica",
      issuer: "Ministerio de Salud",
      url: "https://www.minsalud.gov.co/normatividad_nuevo/Resoluci%C3%B3n%201995%20de%201999.pdf",
      note: "Se aplica aquí por analogía, no por obligación directa: la plataforma no es una historia clínica hospitalaria, pero sí guarda datos clínicos de una persona identificable. De ella se toman el principio de acceso restringido (Art. 14) y la línea base de inmutabilidad y atribución por usuario y fecha (Art. 16 y 18)."
    ),
    Document.new(
      title: "Resolución 866 de 2021 — Interoperabilidad de la historia clínica electrónica",
      issuer: "Ministerio de Salud y MinTIC",
      url: "https://www.minsalud.gov.co/sites/rid/Lists/BibliotecaDigital/RIDE/DE/DIJ/resolucion-866-de-2021.pdf",
      note: "Su Art. 2 define una lista cerrada de nueve categorías de actores obligados; ni los patrocinadores de ensayos clínicos, ni las CRO, ni los centros de investigación como tales aparecen en el texto. La lectura más fuerte es que la plataforma queda fuera del mandato, pero es una inferencia desde el silencio de la norma, no una exención explícita."
    ),
    Document.new(
      title: "Resolución 1888 de 2025 — Resumen Digital de Atención en Salud (RDA)",
      issuer: "Ministerio de Salud",
      url: "https://www.minsalud.gov.co/Normatividad_Nuevo/Resolucion%20No%201888%20de%202025.pdf",
      note: "Complementa el régimen de interoperabilidad; se revisa junto con la Resolución 866 para determinar el alcance."
    ),
    Document.new(
      title: "Circular Externa 005 de 2017 — Países con nivel adecuado de protección de datos",
      issuer: "Superintendencia de Industria y Comercio (SIC)",
      url: "https://normograma.dian.gov.co/dian/compilacion/docs/circular_superindustria_0005_2017.htm",
      note: "Estados Unidos figura en la lista de destinos con protección adecuada, lo que resulta relevante para el alojamiento de la plataforma."
    ),
    Document.new(
      title: "Resolución No. 2008022217 del 14 de agosto de 2008",
      issuer: "INVIMA (Dirección General)",
      url: nil,
      note: "Acto administrativo distinto de la Resolución 2378 de 2008 — no confundir. Se conserva una copia en el repositorio por completitud, pero no sustenta ninguna afirmación de la investigación y su URL de origen no está verificada, por lo que se cita solo por título y debe revisarse antes de usarse formalmente."
    )
  ].freeze

  # Internal analysis produced on top of the sources above. These live in the
  # repository (not served by the app), so they are listed by path, not linked.
  INTERNAL_DOCUMENTS = [
    Document.new(
      title: "docs/investigacion_datos_pacientes_colombia.md",
      issuer: "Investigación interna",
      url: nil,
      note: "Informe completo de la investigación normativa, con el registro de fuentes y la separación explícita entre lo confirmado y lo refutado."
    ),
    Document.new(
      title: "docs/informe_socios_cumplimiento_datos_pacientes.md",
      issuer: "Resumen interno",
      url: nil,
      note: "Resumen no técnico del estado de cumplimiento, dirigido a socios."
    ),
    Document.new(
      title: "docs/sources/README.md",
      issuer: "Índice de fuentes",
      url: nil,
      note: "Mapa entre cada norma y su copia local descargada, con la fecha de descarga."
    )
  ].freeze

  FEATURES = [
    Feature.new(
      name: "Autenticación del personal y solicitud pública de participación",
      status: :done,
      detail: "Devise autentica solo al personal; nadie se registra por su cuenta. Los pacientes no tienen cuenta: desde la ficha pública de un estudio dejan una solicitud de contacto (teléfono o correo) que crea el registro del paciente como interesado, y el representante del centro construye después la historia clínica."
    ),
    Feature.new(
      name: "Roles y permisos por recurso",
      status: :done,
      detail: "Cinco roles con una matriz de permisos por recurso (ver/editar/eliminar), editable por el administrador sin tocar código."
    ),
    Feature.new(
      name: "Activación de cuentas de usuario",
      status: :done,
      detail: "Toda cuenta nace inactiva y no puede iniciar sesión hasta que un administrador la active desde la gestión de usuarios (filtrable por patrocinador, sede, tipo de cuenta o estado). Desactivar a alguien también cierra la sesión que tuviera abierta. Las cuentas de administrador están siempre activas."
    ),
    Feature.new(
      name: "Tipo de estudio y aprobación regulatoria",
      status: :done,
      detail: "Cada estudio se crea explícitamente como observacional o intervencional. El observacional registra la aprobación del comité de ética; el intervencional, la de la autoridad sanitaria local, nombrada según los parámetros locales del país (INVIMA en Colombia)."
    ),
    Feature.new(
      name: "Parámetros locales por país",
      status: :done,
      detail: "Configuración propia de cada jurisdicción (por ahora, el nombre de la autoridad sanitaria), administrada por el administrador y asociada a un país, para no dejar nombres de entidades escritos en el código."
    ),
    Feature.new(
      name: "Control de acceso Pundit, denegado por defecto",
      status: :done,
      detail: "Toda acción estándar se autoriza automáticamente y una autorización faltante rompe las especificaciones. Cierra la exposición previa de datos de pacientes a cualquier usuario autenticado."
    ),
    Feature.new(
      name: "Autorización de habeas data (Ley 1581) en el registro",
      status: :done,
      detail: "Casilla expresa y separada, no incluida en unos términos y condiciones genéricos. Es una barrera dura: sin autorización no se crea cuenta ni dato. Se guarda el texto, su versión, el momento y la IP."
    ),
    Feature.new(
      name: "Cifrado de datos clínicos identificables y código de participante",
      status: :done,
      detail: "Nombre, correo, fecha de nacimiento, contacto e identificación cifrados de forma determinista (consultables); enfermedad y notas, no deterministas. Cada paciente tiene un código que permite ligar identidad y datos de investigación."
    ),
    Feature.new(
      name: "Registro de auditoría con atribución de usuario",
      status: :done,
      detail: "PaperTrail sobre paciente, estudio, consentimiento, perfiles, variables, valores y campañas, con el usuario responsable de cada cambio y una vista de change control. Los campos cifrados y las credenciales se excluyen del registro."
    ),
    Feature.new(
      name: "Motor de criterios de elegibilidad",
      status: :done,
      detail: "Representa las reglas de inclusión y exclusión y las evalúa: compara los valores capturados del paciente contra el perfil del estudio y entrega un veredicto que distingue elegible, no elegible e incompleto. Las respuestas del paciente quedan ligadas a cada regla por identificador, de modo que renombrar una regla ya no desvincula lo capturado."
    ),
    Feature.new(
      name: "Resumen de elegibilidad y promoción del paciente",
      status: :done,
      detail: "La evaluación se presenta como un informe: veredicto, conteos de criterios cumplidos, fuera de alcance y por medir, con el detalle de lo que falta o no se cumple. Desde ahí el representante o investigador promueve al paciente en el ciclo del estudio."
    ),
    Feature.new(
      name: "Información complementaria del paciente",
      status: :done,
      detail: "Exámenes previos del paciente: documentos en PDF, fotografías y notas en texto enriquecido, subidos directamente al bucket de AWS. Visible para el representante del centro y los administradores."
    ),
    Feature.new(
      name: "Resumen de tratamiento del paciente",
      status: :done,
      detail: "Página única para representantes y administradores que consolida el estado del paciente, el veredicto de elegibilidad con lo pendiente y fuera de alcance, y la información complementaria, con las acciones de promoción a la mano."
    ),
    Feature.new(
      name: "Ciclo de vida del paciente",
      status: :done,
      detail: "Máquina de estados interesado → candidato → participante, con las transiciones de descarte y rechazo."
    ),
    Feature.new(
      name: "Salvaguarda de transferencia internacional",
      status: :done,
      detail: "Los patrocinadores se marcan como internacionales y el registro captura una autorización adicional del Art. 26. Es una salvaguarda preventiva: hoy la plataforma no envía datos de pacientes a los patrocinadores."
    ),
    Feature.new(
      name: "Multilenguaje (es/en/fr/pt) y ficha pública de estudio",
      status: :done,
      detail: "Interfaz traducida, búsqueda de estudios por ciudad y ficha pública consultable sin iniciar sesión."
    ),
    Feature.new(
      name: "Módulo de campañas",
      status: :partial,
      detail: "Funciona como biblioteca de contenido: campañas por estudio, documentos, estados y credenciales cifradas por canal. La publicación efectiva en redes está pendiente de la revisión de aplicación de Meta y X."
    ),
    Feature.new(
      name: "Consentimiento informado INVIMA multiparte",
      status: :blocked,
      detail: "Falta por completo el consentimiento firmado por participante, dos testigos y médico investigador, con refirma ante cada modificación del formato. Está detenido hasta que se confirme si la firma digital es válida o se exige firma manuscrita escaneada."
    ),
    Feature.new(
      name: "Confirmación legal INVIMA / Ley 1581",
      status: :pending,
      detail: "Sin resolver: si el consentimiento INVIMA reemplaza o se suma a la autorización de habeas data, si el consentimiento electrónico es válido, y qué acceso tienen patrocinadores y comités de monitoreo a datos identificables. Mientras tanto se construye la versión más exigente: ambos requisitos."
    ),
    Feature.new(
      name: "Contratos de tratamiento con los proveedores de alojamiento",
      status: :pending,
      detail: "Tarea contractual, no de software: firmar los acuerdos con los proveedores de nube y confirmar quién es el responsable del tratamiento. Es lo que legitima alojar los datos fuera del país, junto con el aviso ya incluido en la autorización."
    ),
    Feature.new(
      name: "Composición booleana de criterios",
      status: :pending,
      detail: "Cada variable es una comparación atómica. No hay Y/O ni anidamiento, así que una regla compuesta debe partirse en varias variables y un «o» no puede representarse."
    ),
    Feature.new(
      name: "Semántica temporal en los criterios",
      status: :pending,
      detail: "«En las últimas dos semanas» hoy es texto dentro del nombre de la variable: el motor compara un valor estático y nunca una ventana de fechas."
    ),
    Feature.new(
      name: "Criterios de juicio del investigador",
      status: :pending,
      detail: "Los criterios abiertos («cualquier condición que, a juicio del investigador…») solo pueden modelarse como una casilla booleana."
    ),
    Feature.new(
      name: "Retención y eliminación de datos",
      status: :pending,
      detail: "No hay política ni lógica de retención. El plazo aplicable no está confirmado y la cifra que suele citarse fue descartada en la verificación, así que no debe fijarse en código."
    ),
    Feature.new(
      name: "Notificación de incidentes de seguridad",
      status: :pending,
      detail: "El plazo y la autoridad ante la cual reportar una brecha de datos de salud no están determinados."
    ),
    Feature.new(
      name: "Interoperabilidad IHCE / RDA",
      status: :pending,
      detail: "Probablemente fuera del alcance obligatorio, pero por inferencia desde el silencio de la norma y no por exención explícita. Debe documentarse como tal, no como certeza."
    ),
    Feature.new(
      name: "Especificaciones en integración continua",
      status: :pending,
      detail: "CI corre análisis de seguridad y linting, pero no ejecuta la suite de pruebas: hoy nada impide mezclar código con especificaciones rotas."
    )
  ].freeze

  def self.features_by_status(status)
    FEATURES.select { |feature| feature.status == status }
  end

  def self.shipped
    features_by_status(:done)
  end

  def self.outstanding
    FEATURES.reject { |feature| feature.status == :done }
  end
end
