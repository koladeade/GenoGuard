/// Article text for the Learn section. Plain data so it is easy to edit.
enum BlockType { heading, paragraph, bullets, note }

class Block {
  const Block.heading(this.text) : type = BlockType.heading, items = const [];
  const Block.paragraph(this.text)
    : type = BlockType.paragraph,
      items = const [];
  const Block.note(this.text) : type = BlockType.note, items = const [];
  const Block.bullets(this.items) : type = BlockType.bullets, text = '';

  final BlockType type;
  final String text;
  final List<String> items;
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.minutes,
    required this.blocks,
  });
  final String id;
  final String title;
  final int minutes;
  final List<Block> blocks;
}

const kArticles = <Article>[
  Article(
    id: 'what-is-scd',
    title: 'What is sickle cell disease?',
    minutes: 3,
    blocks: [
      Block.paragraph(
        'Sickle cell disease (SCD) is an inherited condition that affects haemoglobin, the part of red '
        'blood cells that carries oxygen around the body.',
      ),
      Block.paragraph(
        'Healthy red blood cells are round and flexible. In SCD, many cells become hard and curved like a '
        'sickle. They can block small blood vessels, and they break down faster than the body can replace them.',
      ),
      Block.heading('What it can cause'),
      Block.bullets([
        'Sudden, severe pain called a pain crisis, often in the back, chest, arms and legs',
        'Tiredness and paleness from anaemia',
        'Infections, especially in young children',
        'Swollen hands and feet',
        'Damage to organs over time, such as the lungs, kidneys and eyes, and a risk of stroke',
      ]),
      Block.heading('How someone gets it'),
      Block.paragraph(
        'You cannot catch sickle cell disease. It is inherited. A child has SCD when both parents pass on '
        'a sickle gene. A person who carries only one sickle gene (sickle cell trait) is usually healthy '
        'but can pass the gene on. The "Genotypes explained" article shows how this works.',
      ),
      Block.heading('In Nigeria'),
      Block.paragraph(
        'Nigeria has more people living with SCD than any other country. The World Health Organization '
        'estimates that at least 150,000 babies are born with it in Nigeria every year, and researchers '
        'estimate that about one in three babies born with SCD worldwide is Nigerian. Exact numbers are '
        'hard to know because there is no national newborn screening.',
      ),
      Block.heading('Living well with it'),
      Block.paragraph(
        'Treatment and regular care reduce complications and ease pain. A bone marrow transplant can cure '
        'some people, but it is not an option for everyone. Early diagnosis makes a big difference.',
      ),
      Block.note(
        'This is general information, not medical advice. Talk to a doctor about your own care.',
      ),
    ],
  ),
  Article(
    id: 'genotypes',
    title: 'Genotypes explained',
    minutes: 4,
    blocks: [
      Block.paragraph(
        'Your genotype is the pair of haemoglobin genes you inherited, one from each parent. A blood test '
        '(haemoglobin electrophoresis) shows it. It is different from your blood group.',
      ),
      Block.heading('The common genotypes'),
      Block.bullets([
        'AA: normal haemoglobin. No sickle gene.',
        'AS: sickle cell trait. A carrier who is usually healthy and can pass on the S gene.',
        'AC: carries haemoglobin C. Usually healthy and can pass on the C gene.',
        'SS: sickle cell anaemia, the most common form of SCD.',
        'SC: another form of SCD. It is often milder than SS but can still cause serious problems.',
      ]),
      Block.heading('What children can inherit'),
      Block.paragraph(
        'In every pregnancy, each parent passes on one of their two genes by chance. Some examples:',
      ),
      Block.bullets([
        'AS and AS: 25% chance of SS, 50% chance of AS, 25% chance of AA',
        'AS and SS: 50% chance of SS, 50% chance of AS',
        'AS and AC: 25% chance each of AA, AS, AC and SC',
        'SS and SS: every child has SS',
        'AA and any genotype: no child has SS (a child could still be AS or AC)',
      ]),
      Block.paragraph(
        'The chances are the same in every pregnancy. Earlier children do not change them. You can try any '
        'pair with the Test compatibility tool.',
      ),
      Block.note(
        'Genotypes typed into the app are not checked. Only a lab test can confirm a genotype.',
      ),
    ],
  ),
  Article(
    id: 'test-before-marriage',
    title: 'Why test before marriage',
    minutes: 3,
    blocks: [
      Block.paragraph(
        'Many families only learn their genotype after a child is born with sickle cell disease. Testing '
        'earlier gives couples time to understand the chances and plan.',
      ),
      Block.heading('What testing tells you'),
      Block.paragraph(
        'A simple blood test shows your genotype. With your partner\'s genotype, you can see the chance of '
        'sickle cell disease for each pregnancy.',
      ),
      Block.heading('Why it helps'),
      Block.bullets([
        'Informed choices: you learn the chances before big decisions about marriage or children.',
        'Early care: a baby diagnosed early can start treatment, vaccines and check-ups that prevent many '
            'serious problems. Late diagnosis is linked to child deaths.',
        'Less fear: knowing is easier than guessing.',
        'Support: genetic counsellors can talk through your options with you.',
      ]),
      Block.heading('Two things to remember'),
      Block.bullets([
        'A result is not a verdict on a person. Having AS or SS is nothing to be ashamed of, and nobody '
            'should be treated badly because of it.',
        'The decision is yours. A counsellor can explain the chances and options, but they do not make '
            'the choice for you.',
      ]),
      Block.heading('How to get tested'),
      Block.paragraph(
        'Ask a hospital, clinic or laboratory for a haemoglobin electrophoresis test, or ask your doctor '
        'where to go. Partners can then compare results privately. Match by QR in this app lets two people '
        'share genotypes only when both agree.',
      ),
      Block.note('This is general information, not medical advice.'),
    ],
  ),
  Article(
    id: 'pain-crisis',
    title: 'Managing a pain crisis at home',
    minutes: 4,
    blocks: [
      Block.note(
        'This is general information. Follow the plan your own doctor gave you, and do not delay care '
        'if you are unsure.',
      ),
      Block.heading('Start early'),
      Block.paragraph(
        'At the first signs of pain, act straight away. Do not wait for it to get severe.',
      ),
      Block.bullets([
        'Rest somewhere calm and comfortable.',
        'Drink water steadily through the day.',
        'Apply gentle warmth to the painful area. Warm, not hot.',
        'Take the pain medicine your doctor prescribed, the way they told you to. Do not take medicines '
            'that were not prescribed for you.',
        'Keep your body warm. Avoid cold water, cold air and strong air conditioning.',
        'Log the pain in the Pain tab so you can show your doctor.',
      ]),
      Block.heading('Go to hospital straight away if you have'),
      Block.bullets([
        'Pain that is worse than usual or does not ease with your prescribed medicine',
        'A fever of 38.3°C (101°F) or higher',
        'Chest pain, fast or difficult breathing, or a painful cough',
        'Signs of a stroke: a drooping face, weakness or numbness in an arm or leg, trouble speaking, a '
            'sudden severe headache, or sudden loss of vision',
        'A swollen, hard belly, or sudden paleness with extreme tiredness, especially in children',
        'A painful erection lasting more than 2 hours',
      ]),
      Block.paragraph(
        'When you arrive, tell the staff that you have sickle cell disease and say your genotype. Bring a '
        'list of your medicines.',
      ),
      Block.note(
        'In an emergency, go to the nearest hospital. Do not wait to see if it passes.',
      ),
    ],
  ),
];
