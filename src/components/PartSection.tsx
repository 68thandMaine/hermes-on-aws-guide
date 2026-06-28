import type {ReactNode} from 'react';

type PartSectionProps = {
  title: string;
  description: string;
  children: ReactNode;
};

export default function PartSection({
  title,
  description,
  children,
}: PartSectionProps): ReactNode {
  return (
    <section className="part-section">
      <h2 className="part-section__title">{title}</h2>
      <p className="part-section__description">{description}</p>
      <div className="row">{children}</div>
    </section>
  );
}
