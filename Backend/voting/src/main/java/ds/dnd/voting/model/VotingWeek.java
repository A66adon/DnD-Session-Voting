package ds.dnd.voting.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Getter
@Setter
@NoArgsConstructor
public class VotingWeek {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private LocalDate deadline;

    @OneToMany(
            mappedBy = "votingWeek",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    private List<TimeSlot> timeSlots;

    @Column(nullable = false)
    private boolean active;

    public VotingWeek(LocalDate deadline, List<TimeSlot> timeSlots) {
        this.deadline = deadline;
        this.timeSlots = new ArrayList<>();
    }
}
