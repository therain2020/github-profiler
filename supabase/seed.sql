-- GitHub Profiler — Sample seed data for testing
-- Run this after schema.sql to populate some example scores.

INSERT INTO scores (username, github_id, avatar_url, tech_score, engineering_score, collab_score, influence_score, composite_score, profile_tags, summary, created_at)
VALUES
  ('torvalds', 1024025, 'https://avatars.githubusercontent.com/u/1024025?v=4',
   4.8, 4.5, 4.2, 5.0, 4.6,
   ARRAY['Linux内核','C语言','开源领袖','长期维护者'],
   'Linux和Git的创造者，三十年来持续高质量贡献，是开源社区最具影响力的人物之一。',
   NOW() - INTERVAL '3 days'),

  ('gaearon', 810438, 'https://avatars.githubusercontent.com/u/810438?v=4',
   4.5, 4.8, 4.5, 4.5, 4.6,
   ARRAY['React','JavaScript','前端架构','开发者工具'],
   'React核心团队成员，Redux和Create React App作者，技术深度和工程规范均为顶级。',
   NOW() - INTERVAL '2 days'),

  ('sindresorhus', 170270, 'https://avatars.githubusercontent.com/u/170270?v=4',
   4.0, 4.5, 4.0, 4.5, 4.3,
   ARRAY['Node.js','开源工具','开发者体验','高产作者'],
   'NPM生态最高产的开源作者之一，数千个高质量小工具包，极大提升了JavaScript开发者体验。',
   NOW() - INTERVAL '1 day'),

  ('tj', 25254, 'https://avatars.githubusercontent.com/u/25254?v=4',
   4.5, 4.2, 4.3, 4.5, 4.4,
   ARRAY['Node.js','Go','全栈','高产作者'],
   'Express、Koa、Commander.js等众多知名项目的作者，跨语言高产开发者。',
   NOW() - INTERVAL '12 hours'),

  ('kentcdodds', 1500684, 'https://avatars.githubusercontent.com/u/1500684?v=4',
   4.0, 4.5, 4.5, 4.0, 4.3,
   ARRAY['React','测试','教育','社区建设'],
   'React Testing Library作者，通过博客和课程极大推动了前端测试最佳实践。',
   NOW() - INTERVAL '6 hours');
