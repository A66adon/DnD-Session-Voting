package ds.dnd.voting.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;


@NoArgsConstructor
@Getter
@Setter
@Entity
public class Vote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long voteId;

    @Column(nullable = false)
    private String voterName;

    @ManyToMany
    @JoinTable(
            name = "vote_timeslots",
            joinColumns = @JoinColumn(name = "vote_id"),
            inverseJoinColumns = @JoinColumn(name = "timeslot_id")
    )
    private List<TimeSlot> timeslots;

    public Vote(String voterName, List<TimeSlot> timeslots) {
        this.voterName = voterName;
        this.timeslots = timeslots;
    }

}
