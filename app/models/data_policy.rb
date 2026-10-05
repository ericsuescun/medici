# Política de Tratamiento de Datos Personales — the public page at
# /politica-de-datos (StaticPagesController#data_policy).
#
# The six required sections come from Decreto 1377 de 2013, Art. 13 (compiled as
# Decreto 1074 de 2015, Art. 2.2.2.25.3.1), which lists the minimum contents of a
# política de tratamiento:
#   1. razón social, domicilio, dirección, correo y teléfono del Responsable
#   2. el tratamiento y su finalidad
#   3. los derechos del Titular
#   4. el área responsable de peticiones, consultas y reclamos
#   5. el procedimiento para ejercer esos derechos
#   6. fecha de entrada en vigencia y período de vigencia de la base de datos
# Every one of them is present below; do not drop a section without checking that
# list first. The primary sources are in docs/sources/.
#
# **Spanish only, deliberately** — the same decision as OperationManual. This is
# the authoritative text of a Colombian legal instrument; a translation could be
# relied on and then drift from the version that actually binds us. The navbar
# label and the links pointing here ARE localized.
module DataPolicy
  # Bumped on any substantive change. Decreto 1377 Art. 13 requires telling
  # Titulares before a substantive change takes effect, so a bump is a decision,
  # not a typo fix.
  VERSION = "1.0".freeze
  EFFECTIVE_ON = Date.new(2026, 8, 26).freeze

  # Anything still unset renders visibly marked rather than silently blank or,
  # worse, invented. A policy naming the wrong legal entity is worse than one
  # that admits the field is pending.
  PENDING = "PENDIENTE".freeze

  # The identification of the Responsable (required item 1). Real values come
  # from ENV so the legal identity is not buried in a source file:
  #   heroku config:set MEDICI_LEGAL_NAME="..." MEDICI_NIT="..." ...
  def self.responsible
    {
      "Razón social" => env("MEDICI_LEGAL_NAME", "razón social del responsable"),
      "NIT" => env("MEDICI_NIT", "NIT"),
      "Domicilio" => env("MEDICI_CITY", "ciudad de domicilio"),
      "Dirección" => env("MEDICI_ADDRESS", "dirección física"),
      "Correo electrónico" => env("MEDICI_PRIVACY_EMAIL", "correo de protección de datos"),
      "Teléfono" => env("MEDICI_PHONE", "teléfono de contacto")
    }
  end

  def self.env(key, description)
    ENV[key].presence || "#{PENDING}: #{description}"
  end
  private_class_method :env

  def self.pending?(value)
    value.to_s.start_with?(PENDING)
  end

  # True when the policy still names no legal entity — the page shows a warning
  # and `spec/requests/data_policy_spec.rb` documents that publishing it in this
  # state is not the intent.
  def self.complete?
    responsible.values.none? { |v| pending?(v) }
  end

  # A section is a title plus blocks; a block is a paragraph (String) or a
  # bulleted list (Array). Kept as data so the view stays a loop and the specs
  # can assert on the content rather than on markup.
  Section = Struct.new(:id, :title, :blocks, keyword_init: true)

  def self.sections
    [
      Section.new(
        id: "responsable",
        title: "1. Quién es responsable de sus datos",
        blocks: [
          "Medici es una plataforma que conecta a personas interesadas en participar " \
          "en estudios clínicos con los centros de investigación que los adelantan en " \
          "Colombia. El responsable del tratamiento de los datos personales recogidos " \
          "a través de este sitio es:",
          :responsible_table,
          "Cuando usted es contactado por un centro de investigación y se vincula a un " \
          "estudio, ese centro actúa como responsable de la historia clínica que abra a " \
          "su nombre, conforme a la Resolución 1995 de 1999. Esta política cubre los " \
          "datos que usted nos entrega a través de Medici."
        ]
      ),

      Section.new(
        id: "datos",
        title: "2. Qué datos recogemos",
        blocks: [
          "Recogemos únicamente lo necesario para cada paso, y cada paso es voluntario.",
          "**Cuando usted deja sus datos en «¡Quiero participar!»:** un teléfono de " \
          "contacto y/o un correo electrónico, el estudio sobre el que consulta, si está " \
          "diligenciando el formulario por otra persona, y su confirmación de que el " \
          "paciente es mayor de edad. En ese momento registramos también la fecha y la " \
          "dirección IP desde la que otorgó su autorización, como prueba de la misma.",
          "**Si el estudio tiene cuestionario y usted decide responderlo:** sus respuestas " \
          "a las preguntas aprobadas por el comité de ética del estudio, la ciudad donde " \
          "vive, y los exámenes o documentos médicos que quiera adjuntar. Todas las " \
          "preguntas son opcionales y puede marcar «No lo sé» en cualquiera.",
          "**Si un centro de investigación lo vincula a un estudio:** el centro registra la " \
          "información clínica y de identificación que el protocolo exige. Esa información " \
          "la ingresa el personal del centro, no usted.",
          "No recogemos datos de navegación con fines publicitarios salvo que usted lo " \
          "acepte expresamente en el aviso de cookies. Vea la sección 10."
        ]
      ),

      Section.new(
        id: "sensibles",
        title: "3. Datos sensibles y carácter facultativo",
        blocks: [
          "Los datos relativos a la salud son **datos sensibles** conforme al artículo 5 de " \
          "la Ley 1581 de 2012. Manifestar interés en un estudio clínico determinado dice " \
          "algo sobre su salud, y por eso lo tratamos como dato sensible desde el primer " \
          "formulario.",
          "**Usted no está obligado a autorizar el tratamiento de datos sensibles ni a " \
          "responder preguntas que versen sobre ellos.** La respuesta a esas preguntas es " \
          "facultativa. Si decide no autorizar, no podremos ponerlo en contacto con un " \
          "centro de investigación, pero eso no le acarrea ninguna otra consecuencia.",
          "El tratamiento de datos sensibles solo procede con su autorización explícita y " \
          "previa (artículos 6 y 9 de la Ley 1581 de 2012). Sin esa autorización no " \
          "guardamos absolutamente nada: el formulario se rechaza y no queda registro."
        ]
      ),

      Section.new(
        id: "finalidades",
        title: "4. Para qué usamos sus datos",
        blocks: [
          "Sus datos se tratan únicamente para las siguientes finalidades:",
          [
            "Evaluar de manera preliminar si usted podría cumplir los criterios de un " \
            "estudio clínico determinado.",
            "Poner sus datos de contacto a disposición del centro de investigación que " \
            "adelanta ese estudio, para que se comunique con usted.",
            "Comunicarnos con usted sobre el estudio por el que consultó.",
            "Considerarlo para otros estudios en el futuro — **solo si usted lo autoriza " \
            "de manera separada**; no autorizarlo no afecta su participación en el estudio " \
            "por el que consultó.",
            "Cumplir las obligaciones legales aplicables a la investigación clínica en " \
            "Colombia, incluidas las buenas prácticas clínicas (Resolución 2378 de 2008) y " \
            "los requerimientos de autoridades competentes.",
            "Mantener registros de auditoría que permitan reconstruir quién modificó qué " \
            "información y cuándo."
          ],
          "**No vendemos sus datos, no los cedemos con fines publicitarios y no los usamos " \
          "para crear perfiles comerciales.**"
        ]
      ),

      Section.new(
        id: "acceso",
        title: "5. Quién puede ver sus datos",
        blocks: [
          "Conforme al artículo 13 de la Ley 1581 de 2012, la información solo se suministra " \
          "a usted, a sus causahabientes o representantes legales, a las autoridades " \
          "públicas en ejercicio de sus funciones o por orden judicial, y a los terceros que " \
          "usted o la ley autoricen. En la práctica esto significa:",
          [
            "**El equipo del centro de investigación** al que corresponde el estudio por el " \
            "que usted consultó, para evaluarlo y contactarlo.",
            "**El personal administrativo de Medici** estrictamente necesario para operar la " \
            "plataforma.",
            "**Las autoridades competentes** — INVIMA, la Superintendencia de Industria y " \
            "Comercio, autoridades sanitarias y judiciales — cuando lo exija la ley.",
            "**Los comités de ética** que supervisan el estudio, en los términos de las " \
            "buenas prácticas clínicas."
          ],
          "El patrocinador del estudio no recibe de Medici datos que permitan identificarlo " \
          "a usted. La información con la que se analiza un estudio se maneja asociada a un " \
          "código de participante, no a su nombre."
        ]
      ),

      Section.new(
        id: "encargados",
        title: "6. Encargados y alojamiento de la información",
        blocks: [
          "La plataforma se aloja en servidores de proveedores de infraestructura ubicados " \
          "en los Estados Unidos, que actúan como **encargados del tratamiento**: solo " \
          "pueden tratar los datos siguiendo nuestras instrucciones y no pueden usarlos " \
          "para fines propios.",
          "Esto constituye una **transmisión** de datos personales en los términos de la " \
          "normativa colombiana, no una transferencia a un tercero autónomo. Los Estados " \
          "Unidos figura en el listado de países con un nivel adecuado de protección " \
          "declarado por la Superintendencia de Industria y Comercio."
        ]
      ),

      Section.new(
        id: "menores",
        title: "7. Menores de edad",
        blocks: [
          "El artículo 7 de la Ley 1581 de 2012 proscribe el tratamiento de datos personales " \
          "de niñas, niños y adolescentes, salvo los de naturaleza pública. **Medici no " \
          "recoge datos de menores de edad.** El formulario público exige confirmar " \
          "expresamente que el paciente es mayor de edad antes de guardar cualquier dato.",
          "Si detectamos que hemos recibido datos de una persona menor de edad, los " \
          "suprimimos. Si usted cree que esto ha ocurrido, escríbanos a la dirección de la " \
          "sección 9."
        ]
      ),

      Section.new(
        id: "derechos",
        title: "8. Sus derechos como titular",
        blocks: [
          "El artículo 8 de la Ley 1581 de 2012 le reconoce los siguientes derechos:",
          [
            "**Conocer, actualizar y rectificar** sus datos personales, especialmente " \
            "cuando sean parciales, inexactos, incompletos, fraccionados o induzcan a error.",
            "**Solicitar prueba de la autorización** que usted nos otorgó, salvo en los " \
            "casos en que la ley exceptúa este requisito.",
            "**Ser informado**, previa solicitud, sobre el uso que le hemos dado a sus datos.",
            "**Presentar quejas ante la Superintendencia de Industria y Comercio** por " \
            "infracciones a la ley.",
            "**Revocar la autorización y/o solicitar la supresión** de sus datos, en los " \
            "términos del artículo 8, literal e).",
            "**Acceder de forma gratuita** a sus datos personales objeto de tratamiento."
          ],
          "Estos derechos los ejerce usted, sus causahabientes, su representante legal o su " \
          "apoderado, acreditando previamente su identidad."
        ]
      ),

      Section.new(
        id: "procedimiento",
        title: "9. Cómo ejercer sus derechos",
        blocks: [
          "**Área responsable.** Las peticiones, consultas y reclamos los atiende el área de " \
          "protección de datos personales de Medici, en el correo electrónico indicado en " \
          "la sección 1.",
          "**Qué debe incluir su solicitud.** Su nombre completo y número de documento, sus " \
          "datos de contacto, la descripción de lo que solicita y, si actúa en " \
          "representación de otra persona, el documento que lo acredite.",
          "**Consultas** (artículo 14 de la Ley 1581 de 2012). Se atienden en un término " \
          "máximo de **diez (10) días hábiles** contados desde el recibo. Si no fuere " \
          "posible atenderla en ese término, le informaremos los motivos y la fecha en que " \
          "se atenderá, que en ningún caso superará los **cinco (5) días hábiles** " \
          "siguientes al vencimiento del primer plazo.",
          "**Reclamos** (artículo 15 de la Ley 1581 de 2012). Si su reclamo resulta " \
          "incompleto, lo requeriremos dentro de los cinco (5) días siguientes para que lo " \
          "subsane; si pasan dos (2) meses sin respuesta suya, se entenderá que ha " \
          "desistido. Recibido el reclamo completo, incluiremos en la base de datos la " \
          "leyenda «reclamo en trámite» en un término no mayor a dos (2) días hábiles, y la " \
          "mantendremos hasta que el reclamo se decida. El término máximo para atenderlo es " \
          "de **quince (15) días hábiles** contados desde el día siguiente a su recibo, " \
          "prorrogables por **ocho (8) días hábiles** más, informándole los motivos.",
          "**Antes de acudir a la Superintendencia.** El artículo 16 de la Ley 1581 de 2012 " \
          "exige haber agotado primero el trámite de consulta o reclamo ante nosotros.",
          "**Límites de la supresión.** Cuando usted ya se encuentre vinculado a un estudio " \
          "clínico, las normas de buenas prácticas clínicas obligan a conservar ciertos " \
          "registros de la investigación. En ese caso suprimiremos todo lo que la ley " \
          "permita suprimir y le explicaremos qué debe conservarse y por qué."
        ]
      ),

      Section.new(
        id: "seguridad",
        title: "10. Seguridad y medición del sitio",
        blocks: [
          "**Medidas de seguridad.** Los campos que permiten identificarlo se almacenan " \
          "cifrados en la base de datos. A cada paciente se le asigna un código de " \
          "participante, de modo que la información del estudio pueda manejarse sin usar su " \
          "nombre. El acceso está restringido por rol y cada modificación queda registrada " \
          "con el usuario que la hizo y la fecha.",
          "**Cookies y medición.** Usamos herramientas de medición de Google y de Meta para " \
          "entender cómo llegan las personas al sitio y mejorar nuestras campañas. " \
          "**Ninguna de ellas se activa hasta que usted lo acepte** en el aviso que aparece " \
          "al pie de la página, y puede rechazarlas sin perder ninguna funcionalidad.",
          "Estas herramientas **no se cargan** en el formulario de participación ni en el " \
          "cuestionario clínico, y nunca reciben su nombre, su teléfono, su correo ni sus " \
          "respuestas. Tampoco reciben cuál es el estudio que usted consultó."
        ]
      ),

      Section.new(
        id: "vigencia",
        title: "11. Vigencia",
        blocks: [
          :validity,
          "**Período de vigencia de la base de datos.** Sus datos se conservan mientras se " \
          "mantenga la finalidad que justificó recogerlos y por el término que exijan las " \
          "normas aplicables a la investigación clínica y a los registros de salud en " \
          "Colombia. Cumplido ese término, se suprimen.",
          "**Cambios.** Cualquier cambio sustancial en esta política le será comunicado " \
          "oportunamente antes de que empiece a aplicarse, conforme al Decreto 1074 de 2015."
        ]
      )
    ]
  end
end
